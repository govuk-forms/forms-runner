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

  def journey(locale: :en)
    return welsh_journey if locale.to_sym == :cy

    english_journey
  end

  def form
    @form ||= form_from_document
  end

  def welsh_form
    @welsh_form ||= Form.new(welsh_form_document_resource) if welsh_form_document
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

  def delivery_status
    delivery_statuses = deliveries.map(&:status)

    return :failed if delivery_statuses.include?(:failed)
    return :pending if delivery_statuses.include?(:pending)

    :delivered
  end

  def self.sent?(reference)
    submission = Submission.find_by(reference: reference)
    submission&.deliveries&.immediate&.all? { |d| d.delivery_reference.present? }
  end

  def mode_object
    Mode.new(mode)
  end

  def answer_content_for_email_markdown(heading_level:, locale: :en, confirmation_email: false)
    ses_email_formatter(locale, confirmation_email).build_question_answers_section_markdown(heading_level:)
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

  def ses_email_formatter(locale, confirmation_email)
    SesEmailFormatter.new(submission_reference: reference, steps: journey(locale:).completed_steps,
                          confirmation_email:)
  end

  def english_journey
    @english_journey ||= Flow::Journey.new(answer_store:, form_document: form_document_resource)
  end

  def welsh_journey
    @welsh_journey ||= Flow::Journey.new(answer_store:, form_document: welsh_form_document_resource)
  end

  def welsh_form_document_resource
    @welsh_form_document_resource ||= Api::V2::FormDocumentResource.new(welsh_form_document, true)
  end
end
