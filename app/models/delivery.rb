class Delivery < ApplicationRecord
  has_many :submission_deliveries, dependent: :destroy
  has_many :submissions, through: :submission_deliveries

  scope :pending, -> { where(delivered_at: nil, failed_at: nil) }
  scope :delivered, -> { where.not(delivered_at: nil).where(failed_at: nil).or(where("#{table_name}.delivered_at > failed_at")) }
  scope :failed, -> { where.not(failed_at: nil).where(delivered_at: nil).or(where("#{table_name}.delivered_at <= failed_at")) }

  scope :bounced_on_day, lambda { |date|
    range = date.in_time_zone(TimeZoneUtils.submission_time_zone).all_day
    failed.where(failure_reason: "bounced", failed_at: range)
  }

  enum :delivery_schedule, {
    immediate: "immediate",
    daily: "daily",
    weekly: "weekly",
  }

  def status
    return :pending if delivered_at.nil? && failed_at.nil?
    return :delivered if delivered_at.present? && failed_at.nil?
    return :failed if failed_at.present? && delivered_at.nil?

    delivered_at > failed_at ? :delivered : :failed
  end

  %i[pending delivered failed].each do |status|
    define_method("#{status}?") do
      self.status == status
    end
  end

  def new_attempt!
    update!(
      last_attempt_at: Time.zone.now,
      delivered_at: nil,
      failed_at: nil,
      failure_reason: nil,
      failure_details: nil,
    )
  end

  def form_id
    submissions.first&.form_id
  end

  def form
    submissions.first&.form
  end
end
