class Submission < ApplicationRecord
  has_many :submission_deliveries, dependent: :destroy
  has_many :deliveries, through: :submission_deliveries

  scope :for_form_and_mode, lambda { |form_id, mode|
    where(form_id: form_id, mode: mode)
  }

  scope :on_day, lambda { |date|
    range = date.in_time_zone(TimeZoneUtils.submission_time_zone).all_day
    where(created_at: range)
  }

  scope :in_week, lambda { |time_in_week|
    range = time_in_week.in_time_zone(TimeZoneUtils.submission_time_zone).all_week(:monday)
    where(created_at: range)
  }

  scope :ordered_by_form_version_and_date, lambda {
    order(Arel.sql("(form_document->>'updated_at')::timestamptz ASC, created_at ASC"))
  }

  delegate :preview?, to: :mode_object

  encrypts :answers

  def journey
    @journey ||= Flow::Journey.new(answer_store:, form_document: form_document_resource)
  end

  def form
    @form ||= form_from_document
  end

  def submission_time
    created_at.in_time_zone(TimeZoneUtils.submission_time_zone)
  end

  def payment_url
    form.payment_url_with_reference(reference)
  end

  def single_submission_delivery
    deliveries.immediate.sole
  end

  def self.sent?(reference)
    submission = Submission.find_by(reference: reference)
    submission&.single_submission_delivery&.delivery_reference&.present?
  end

  def mode_object
    Mode.new(mode)
  end

private

  def answer_store
    Store::DatabaseAnswerStore.new(answers)
  end

  def form_from_document
    Form.new(form_document_resource)
  end

  def form_document_resource
    @form_document_resource ||= Api::V2::FormDocumentResource.new(form_document, true)
  end
end
