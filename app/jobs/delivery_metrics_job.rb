class DeliveryMetricsJob < ApplicationJob
  queue_as :metrics

  # Record a value for every mode, so that a missing series means the metric has stopped being reported
  MODES = %w[form preview-draft preview-live preview-archived].freeze

  def perform(*_args)
    safely_record_metric("submissions without immediate delivery") { record_submissions_without_immediate_delivery }
    safely_record_metric("oldest undelivered delivery age") { record_oldest_undelivered_delivery_age }
  end

private

  def record_submissions_without_immediate_delivery
    counts = Submission.without_immediate_delivery.group(:mode).count

    MODES.each do |mode|
      Metrics.record_submissions_without_immediate_delivery(counts.fetch(mode, 0), mode:)
    end
  end

  def record_oldest_undelivered_delivery_age
    oldest_created_at = Delivery.immediate.undelivered
      .joins(:submissions)
      .group("submissions.mode", :delivery_method)
      .minimum("submissions.created_at")

    MODES.each do |mode|
      Delivery.delivery_methods.each_value do |delivery_method|
        created_at = oldest_created_at[[mode, delivery_method]]
        Metrics.record_oldest_undelivered_delivery_age(age_in_seconds(created_at), mode:, delivery_method:)
      end
    end
  end

  def age_in_seconds(created_at)
    return 0 if created_at.nil?

    (Time.current - created_at).round
  end

  def safely_record_metric(metric_name)
    yield
  rescue StandardError => e
    Rails.logger.warn("DeliveryMetricsJob failed to record #{metric_name} metric - #{e.class.name}: #{e.message}")
    Sentry.capture_exception(e)
  end
end
