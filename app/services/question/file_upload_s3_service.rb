class Question::FileUploadS3Service
  GUARD_DUTY_MALWARE_SCAN_STATUS = "GuardDutyMalwareScanStatus".freeze

  class PollForScanResultTimeoutError < StandardError; end

  def initialize
    @s3 = Aws::S3::Client.new
    @bucket = Settings.aws.file_upload_s3_bucket_name
    @poll_scan_status_attempts = Settings.file_upload.poll_scan_status_max_attempts.to_i
    @poll_scan_status_wait_seconds = Settings.file_upload.poll_scan_status_wait_milliseconds.to_f / 1000
  end

  def upload_to_s3(file, key)
    @s3.put_object({
      body: file,
      bucket: @bucket,
      key:,
    })
    key
  end

  def extend_life(key)
    @s3.copy_object({
      key: key,
      bucket: @bucket,
      copy_source: "#{@bucket}/#{key}",
      metadata: { "extended_at" => Time.current.iso8601 },
      metadata_directive: "REPLACE",
      tagging_directive: "REPLACE",
    })
    FileUploadLogger.log_s3_operation(key, "Extended life of file in S3")
  end

  def file_from_s3(key)
    file = @s3.get_object({
      bucket: @bucket,
      key:,
    }).body.read
    FileUploadLogger.log_s3_operation(key, "Retrieved uploaded file from S3")
    file
  rescue Aws::S3::Errors::NoSuchKey
    FileUploadLogger.log_s3_operation_error(key, "Object with key does not exist in S3")
    raise
  end

  def delete_from_s3(key)
    @s3.delete_object({
      bucket: @bucket,
      key:,
    })
    FileUploadLogger.log_s3_operation(key, "Deleted uploaded file from S3", { s3_object_key: key })
  end

  def poll_for_scan_status(key)
    @poll_scan_status_attempts.times do |i|
      scan_status_tag = get_scan_status(key)
      Rails.logger.debug "Polled S3 object to get GuardDuty scan status for uploaded file. Attempt: #{i + 1} of 20"

      if scan_status_tag.present?
        FileUploadLogger.log_s3_operation(key, "Successfully got GuardDuty scan status for uploaded file", {
          scan_status: scan_status_tag[:value],
          scan_status_poll_attempts: i + 1,
        })
        return scan_status_tag[:value]
      end

      sleep @poll_scan_status_wait_seconds
    end

    raise PollForScanResultTimeoutError
  end

private

  def get_scan_status(key)
    tag_set = get_s3_object_tagging(key)
    tag_set.detect { |tag| tag[:key] == GUARD_DUTY_MALWARE_SCAN_STATUS }
  end

  def get_s3_object_tagging(key)
    response = @s3.get_object_tagging({
      bucket: @bucket,
      key:,
    })
    response.to_h[:tag_set]
  end
end
