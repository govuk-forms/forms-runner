class FormSubmissionService
  include RedactionUtils

  class ConfirmationEmailToAddressError < StandardError; end

  class << self
    def call(**args)
      new(**args)
    end
  end

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

    submission = create_submission_record
    enqueue_deliveries(submission)

    LogEventService.log_submit(
      current_context,
      requested_email_confirmation: requested_confirmation?,
      preview: mode.preview?,
    )

    enqueue_send_confirmation_email_job(submission:) if requested_confirmation? || send_copy_of_answers?

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

    @welsh_form = form if form.welsh?
    @form = Form.new(english_form_document)
  end

  def welsh_form_document
    return unless submission_locale == :cy
    return @welsh_form.document_json if @welsh_form.present?

    Api::V2::FormDocumentRepository.find_with_mode(form_id: form.id, mode:, language: :cy)
  end

  def validate_submission
    raise StandardError, "Form id(#{form.id}) has no completed steps i.e questions/answers to submit" if current_context.completed_steps.blank?
  end

  def enqueue_deliveries(submission)
    form.delivery_configurations
        .filter { |c| c.delivery_schedule == "immediate" }
        .each { |c| enqueue_delivery(c, submission) }
  end

  def enqueue_delivery(delivery_configuration, submission)
    delivery = submission.deliveries.create!(
      delivery_schedule: :immediate,
      delivery_method: delivery_configuration.delivery_method,
      formats: delivery_configuration.formats,
    )

    job_class = resolve_submission_job_class(delivery_configuration)
    enqueue_deliver_submission_job(job_class, submission, delivery)
  end

  def resolve_submission_job_class(delivery_configuration)
    case delivery_configuration.delivery_method
    when "s3"
      SendS3SubmissionJob
    when "email"
      SendSubmissionJob
    else
      raise "unrecognized delivery method #{delivery_configuration.delivery_method.inspect}"
    end
  end

  def create_submission_record
    Submission.create!(
      reference: submission_reference,
      form_id: form.id,
      answers: current_context.answers,
      mode: mode,
      form_document: form.document_json,
      welsh_form_document: welsh_form_document,
      submission_locale:,
      created_at: timestamp,
    )
  end

  def enqueue_deliver_submission_job(job_class, submission, delivery)
    job_class.perform_later(delivery) do |job|
      next if job.successfully_enqueued?

      delivery.destroy!
      submission.destroy! if submission.deliveries.reload.empty?

      message_suffix = ": #{job.enqueue_error&.message}" if job.enqueue_error
      raise StandardError, "Failed to enqueue delivery for method #{delivery.delivery_method} for submission with reference #{submission_reference}#{message_suffix}"
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
      confirmation_email_address: confirmation_email_address,
      include_copy_of_answers: send_copy_of_answers?,
    ) do |job|
      next if job.successfully_enqueued?

      message_suffix = ": #{job.enqueue_error&.message}" if job.enqueue_error
      raise StandardError, "Failed to enqueue confirmation email for reference #{submission_reference}#{message_suffix}"
    end
  end

  def requested_confirmation?
    email_confirmation_input.send_confirmation == "send_email"
  end

  def send_copy_of_answers?
    @current_context.will_send_copy_of_answers?
  end

  def confirmation_email_address
    if send_copy_of_answers?
      @current_context.get_copy_of_answers_email_address
    else
      email_confirmation_input.confirmation_email_address
    end
  end
end
