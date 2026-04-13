class FormSubmissionService
  include RedactionUtils

  class ConfirmationEmailToAddressError < StandardError; end

  class << self
    def call(**args)
      new(**args)
    end
  end

  MailerOptions = Data.define(:title, :is_preview, :timestamp, :submission_reference, :payment_url)

  def initialize(current_context:, email_confirmation_input:, mode:)
    @current_context = current_context
    @form = current_context.form
    @email_confirmation_input = email_confirmation_input
    @mode = mode
    @timestamp = submission_timestamp
    @submission_reference = ReferenceNumberService.generate

    CurrentRequestLoggingAttributes.submission_reference = submission_reference
  end

  def submit
    ensure_form_english

    validate_submission
    validate_confirmation_email_address if requested_confirmation?

    submission = deliver_submission
    enqueue_send_confirmation_email_job(submission:) if requested_confirmation?

    submission_reference
  end

  def submission_locale
    return :cy if current_context.locales_used.present? && current_context.locales_used.include?(:cy)

    :en
  end

private

  attr_accessor :current_context, :form, :email_confirmation_input, :mode, :timestamp, :submission_reference, :localised_form

  def ensure_form_english
    return if form.english?

    fetch_english_language_form
  end

  def fetch_english_language_form
    english_form_document = Api::V2::FormDocumentRepository.find_with_mode(form_id: form.id, mode:)

    raise ActiveResource::ResourceNotFound.new(404, "Not Found") if english_form_document.nil?

    @form = Form.new(english_form_document)
  end

  def validate_submission
    raise StandardError, "Form id(#{form.id}) has no completed steps i.e questions/answers to submit" if current_context.completed_steps.blank?
  end

  def deliver_submission
    submission =
      case form.submission_type
      when "s3"
        enqueue_deliver_submission_job(SendS3SubmissionJob)
      when "email"
        enqueue_deliver_submission_job(SendSubmissionJob)
      else
        raise "unrecognized submission delivery method #{form.submission_type.inspect}"
      end

    LogEventService.log_submit(
      current_context,
      requested_email_confirmation: requested_confirmation?,
      preview: mode.preview?,
      submission_type: form.submission_type,
      submission_format: form.submission_format,
    )

    submission
  end

  def create_submission_record
    submission = Submission.create!(
      reference: submission_reference,
      form_id: form.id,
      answers: current_context.answers,
      mode: mode,
      form_document: form.document_json,
      submission_locale:,
      created_at: timestamp,
    )

    submission.deliveries.create!(delivery_schedule: :immediate)

    submission
  end

  def enqueue_deliver_submission_job(job_class)
    submission = create_submission_record

    job_class.perform_later(submission) do |job|
      next if job.successfully_enqueued?

      submission.destroy!
      message_suffix = ": #{job.enqueue_error&.message}" if job.enqueue_error
      raise StandardError, "Failed to enqueue submission for reference #{submission_reference}#{message_suffix}"
    end

    submission
  end

  def submission_timestamp
    time_zone = Rails.configuration.x.submission.time_zone || "UTC"
    Time.use_zone(time_zone) { Time.zone.now }
  end

  def validate_confirmation_email_address
    mail = Mail.new(to: email_confirmation_input.confirmation_email_address)
    to_address_error = mail.errors.select { |error| error[0] == "To" }.first
    return unless to_address_error

    redacted_error = redact_emails_from_sentry_message(to_address_error[2].to_s)
    Sentry.capture_message("ActionMailer error for To email address in confirmation email", extra: {
      action_mailer_error: redacted_error,
    })
    raise ConfirmationEmailToAddressError
  end

  def enqueue_send_confirmation_email_job(submission:)
    SendConfirmationEmailJob.perform_later(
      submission:,
      notify_response_id: email_confirmation_input.confirmation_email_reference,
      confirmation_email_address: email_confirmation_input.confirmation_email_address,
    ) do |job|
      next if job.successfully_enqueued?

      message_suffix = ": #{job.enqueue_error&.message}" if job.enqueue_error
      raise StandardError, "Failed to enqueue confirmation email for reference #{submission_reference}#{message_suffix}"
    end
  end

  def requested_confirmation?
    email_confirmation_input.send_confirmation == "send_email"
  end
end
