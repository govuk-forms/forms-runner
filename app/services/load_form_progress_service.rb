class LoadFormProgressService
  def initialize(current_context:, user_id:, mode:)
    @current_context = current_context
    @user_id = user_id
    @mode = mode
  end

  def load!
    incomplete_submission = IncompleteSubmission.find_by(user_id: @user_id, form_id: @current_context.form.id, mode: @mode.to_s)
    return nil unless incomplete_submission

    @current_context.clear
    @current_context.clear_submission_details

    answers = answers_without_missing_files(incomplete_submission.answers)
    @current_context.load_answers(answers)
    @current_context.add_locale(incomplete_submission.locale)

    @current_context.set_submission_uuid(incomplete_submission.submission_uuid)
    CurrentRequestLoggingAttributes.submission_uuid = incomplete_submission.submission_uuid

    EventLogger.log_form_event("incomplete_submission_loaded")

    incomplete_submission
  end

private

  def answers_without_missing_files(answers)
    return answers if answers.blank?

    answers.select do |_page_id, answer|
      key = Question::File.uploaded_file_key_from(answer)
      key.nil? || uploaded_file_exists?(key)
    end
  end

  def uploaded_file_exists?(key)
    return true if file_upload_s3_service.file_exists?(key)

    FileUploadLogger.log_s3_operation(key, "Uploaded file for saved answer no longer exists in S3, not loading answer")
    false
  end

  def file_upload_s3_service
    @file_upload_s3_service ||= Question::FileUploadS3Service.new
  end
end
