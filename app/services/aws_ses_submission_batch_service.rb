class AwsSesSubmissionBatchService
  def initialize(submissions_query:, form:, mode:)
    @submissions_query = submissions_query
    @form = form
    @mode = mode
  end

  def send_daily_batch(date:)
    files = build_csv_files do |csv_version|
      SubmissionFilenameGenerator.daily_batch_csv_filename(
        form_name: @form.name,
        mode: @mode,
        csv_version:,
        date:,
      )
    end

    mail = AwsSesSubmissionBatchMailer.daily_submission_batch_email(form: @form, date:, mode: @mode, files:).deliver_now

    CurrentJobLoggingAttributes.delivery_reference = mail.message_id
    mail.message_id
  end

  def send_weekly_batch(begin_date:, end_date:)
    files = build_csv_files do |csv_version|
      SubmissionFilenameGenerator.weekly_batch_csv_filename(
        form_name: @form.name,
        mode: @mode,
        csv_version:,
        begin_date: begin_date,
        end_date: end_date,
      )
    end

    mail = AwsSesSubmissionBatchMailer.weekly_submission_batch_email(
      form: @form,
      begin_date:,
      end_date:,
      mode: @mode,
      files:,
    ).deliver_now

    CurrentJobLoggingAttributes.delivery_reference = mail.message_id
    mail.message_id
  end

private

  def build_csv_files(&block)
    files = {}

    csvs = CsvGenerator.generate_batched_submissions(submissions_query: @submissions_query, is_s3_submission: false)
    csvs.each.with_index(1) do |csv, index|
      csv_version = csvs.size > 1 ? index : nil
      filename = block.call(csv_version)
      files[filename] = csv
    end

    files
  end
end
