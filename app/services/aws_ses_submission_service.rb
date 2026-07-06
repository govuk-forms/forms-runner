class AwsSesSubmissionService
  include SubmissionFilenameGenerator

  def initialize(submission:)
    @submission = submission
    @journey = submission.journey
    @form = submission.form
  end

  def submit
    if !@submission.preview? && @form.submission_email.blank?
      raise StandardError, "Form id(#{@form.id}) is missing a submission email address"
    end

    if @form.submission_email.blank? && @submission.preview?
      Rails.logger.info "Skipping sending submission email for preview submission, as the submission email address has not been set"
      return
    end

    deliver_submission_email
  end

private

  def deliver_submission_email
    files = uploaded_files_in_answers

    csv_filename = nil
    if @form.submission_format.include? "json"
      json_filename = generate_json_filename
      files.merge!({ json_filename => generate_json_submission })
    end
    if @form.submission_format.include? "csv"
      csv_filename = generate_csv_filename
      files.merge!({ csv_filename => generate_csv_submission })
    end

    mail = AwsSesFormSubmissionMailer.submission_email(submission: @submission,
                                                       files:,
                                                       csv_filename:,
                                                       json_filename:).deliver_now

    CurrentJobLoggingAttributes.delivery_reference = mail.message_id
    mail.message_id
  end

  def generate_csv_submission
    CsvGenerator.generate_submission(
      submission: @submission,
      is_s3_submission: false,
    )
  end

  def generate_json_submission
    JsonSubmissionGenerator.generate_submission(
      submission: @submission,
      is_s3_submission: false,
    )
  end

  def uploaded_files_in_answers
    questions = @journey.completed_file_upload_questions

    questions_with_errors = questions.filter { it.invalid?(:submission) }
    if questions_with_errors.any?
      errors = questions_with_errors.to_h { [it.question_text, it.errors.details] }
      raise "One or more file answers are invalid:\n#{errors.inspect.indent(2)}"
    end

    files =
      questions
        .map { |question| [question.email_filename(submission_reference: @submission.reference), question.file_from_s3] }
        .to_h

    raise "Duplicate email attachment filenames for submission" if files.count != questions.count

    files
  end

  def generate_csv_filename
    SubmissionFilenameGenerator.csv_filename(form_name: @form.name, submission_reference: @submission.reference)
  end

  def generate_json_filename
    SubmissionFilenameGenerator.json_filename(form_name: @form.name, submission_reference: @submission.reference)
  end
end
