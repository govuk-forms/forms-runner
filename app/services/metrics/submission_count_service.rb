module Metrics
  class SubmissionCountService
    METRIC_NAME = "SubmissionCount".freeze
    METRICS_NAMESPACE = CloudWatchService::FORM_METRICS_NAMESPACE
    REGION = CloudWatchService::REGION
    BATCH_SIZE = 500

    def publish_submission_counts
      metric_count = 0

      submission_counts_by_form_id.each_slice(BATCH_SIZE) do |batch|
        cloudwatch_client.put_metric_data(
          namespace: METRICS_NAMESPACE,
          metric_data: batch.map { |(form_id, count)| metric_datum(form_id:, count:) },
        )
        metric_count += batch.size
      end

      Rails.logger.info "Published #{metric_count} submission count metrics to CloudWatch"
    rescue Aws::CloudWatch::Errors::ServiceError,
           Aws::Errors::MissingCredentialsError => e
      Sentry.capture_exception(e)
      raise
    end

  private

    def submission_counts_by_form_id
      Submission.where(mode: "form").group(:form_id).count
    end

    def metric_datum(form_id:, count:)
      {
        metric_name: METRIC_NAME,
        dimensions: [
          environment_dimension,
          form_id_dimension(form_id),
        ],
        value: count,
        unit: "Count",
        timestamp: Time.zone.now,
      }
    end

    def environment_dimension
      {
        name: "Environment",
        value: Settings.forms_env.downcase,
      }
    end

    def form_id_dimension(form_id)
      {
        name: "FormId",
        value: form_id.to_s,
      }
    end

    def cloudwatch_client
      @cloudwatch_client ||= Aws::CloudWatch::Client.new(region: REGION)
    end
  end
end
