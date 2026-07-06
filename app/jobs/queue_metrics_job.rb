class QueueMetricsJob < ApplicationJob
  queue_as :metrics

  def perform(*_args)
    # rubocop:disable Rails/FindEach
    SolidQueue::Queue.all.each do |queue|
      safely_record_metric(queue.name, "queue length") do
        CloudWatchService.record_queue_length_metric(queue.name, queue.size)
      end

      safely_record_metric(queue.name, "failed executions") do
        failed_executions_count = SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { queue_name: queue.name }).count
        CloudWatchService.record_failed_job_executions(queue.name, failed_executions_count)
      end
    end
    # rubocop:enable Rails/FindEach
  end

private

  def safely_record_metric(queue_name, metric_name)
    yield
  rescue StandardError => e
    Rails.logger.warn(
      "QueueMetricsJob failed to record #{metric_name} metric for queue #{queue_name} - #{e.class.name}: #{e.message}",
    )
    Sentry.capture_exception(e)
  end
end
