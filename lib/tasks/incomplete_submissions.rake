namespace :incomplete_submissions do
  desc "List metadata for the incomplete submissions saved by a user, given their GOV.UK One Login email address"
  task :list_for_email, %i[email] => :environment do |_, args|
    email = args[:email]

    usage_message = "usage: rake incomplete_submissions:list_for_email[<email>]".freeze
    abort usage_message if email.blank?

    incomplete_submissions = IncompleteSubmission.for_email(email).order(:created_at)

    puts "Found #{incomplete_submissions.length} incomplete submissions for the email address"

    incomplete_submissions.each do |incomplete_submission|
      puts "form_id: #{incomplete_submission.form_id}, " \
           "form_version: #{incomplete_submission.form_version}, " \
           "submission_uuid: #{incomplete_submission.submission_uuid}, " \
           "created_at: #{incomplete_submission.created_at}, " \
           "updated_at: #{incomplete_submission.updated_at}"
    end
  end

  desc "Delete an incomplete submission given its submission_uuid"
  task :delete_by_submission_uuid, %i[submission_uuid] => :environment do |_, args|
    submission_uuid = args[:submission_uuid]

    usage_message = "usage: rake incomplete_submissions:delete_by_submission_uuid[<submission_uuid>]".freeze
    abort usage_message if submission_uuid.blank?

    incomplete_submission = IncompleteSubmission.find_by(submission_uuid:)
    abort "Incomplete submission with submission_uuid #{submission_uuid} not found" if incomplete_submission.nil?

    uploaded_file_keys = incomplete_submission.uploaded_file_keys
    if uploaded_file_keys.any?
      file_upload_s3_service = Question::FileUploadS3Service.new
      uploaded_file_keys.each { |key| file_upload_s3_service.delete_from_s3(key) }
    end

    incomplete_submission.destroy!

    puts "Deleted incomplete submission with submission_uuid #{submission_uuid} for form #{incomplete_submission.form_id}"
  end
end
