class AwsSesSubmissionBatchMailerPreview < ActionMailer::Preview
  include FactoryBot::Syntax::Methods

  def daily_submission_batch_email
    form = build(:form, submission_email: "testing@gov.uk")
    AwsSesSubmissionBatchMailer.daily_submission_batch_email(form:,
                                                             date: Time.zone.now,
                                                             mode: Mode.new("form"),
                                                             files: { "batch.csv" => "Hello world" })
  end

  def daily_submission_batch_email_preview
    form = build(:form, submission_email: "testing@gov.uk")
    AwsSesSubmissionBatchMailer.daily_submission_batch_email(form:,
                                                             date: Time.zone.now,
                                                             mode: Mode.new("preview-draft"),
                                                             files: { "batch.csv" => "Hello world" })
  end

  def daily_submission_batch_email_with_multiple_files
    form = build(:form, submission_email: "testing@gov.uk")
    AwsSesSubmissionBatchMailer.daily_submission_batch_email(form:,
                                                             date: Time.zone.now,
                                                             mode: Mode.new("form"),
                                                             files: {
                                                               "batch.csv" => "Hello world",
                                                               "batch_2.csv" => "Hello again",
                                                             })
  end

  def weekly_submission_batch_email
    form = build(:form, submission_email: "testing@gov.uk")
    AwsSesSubmissionBatchMailer.weekly_submission_batch_email(form:,
                                                              begin_date: Time.zone.now - 7.days,
                                                              end_date: Time.zone.now,
                                                              mode: Mode.new("form"),
                                                              files: { "batch.csv" => "Hello world" })
  end

  def weekly_submission_batch_email_preview
    form = build(:form, submission_email: "testing@gov.uk")
    AwsSesSubmissionBatchMailer.weekly_submission_batch_email(form:,
                                                              begin_date: Time.zone.now - 7.days,
                                                              end_date: Time.zone.now,
                                                              mode: Mode.new("preview-draft"),
                                                              files: { "batch.csv" => "Hello world" })
  end

  def weekly_submission_batch_email_with_multiple_files
    form = build(:form, submission_email: "testing@gov.uk")
    AwsSesSubmissionBatchMailer.weekly_submission_batch_email(form:,
                                                              begin_date: Time.zone.now - 7.days,
                                                              end_date: Time.zone.now,
                                                              mode: Mode.new("form"),
                                                              files: {
                                                                "batch.csv" => "Hello world",
                                                                "batch_2.csv" => "Hello again",
                                                              })
  end
end
