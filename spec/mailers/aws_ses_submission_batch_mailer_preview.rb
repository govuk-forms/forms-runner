class AwsSesSubmissionBatchMailerPreview < ActionMailer::Preview
  include FactoryBot::Syntax::Methods

  def daily_submission_batch_email
    form = Form.new(build(:v2_form_document, submission_email: "testing@gov.uk"))
    AwsSesSubmissionBatchMailer.daily_submission_batch_email(form:,
                                                             date: Time.zone.now,
                                                             mode: Mode.new("form"),
                                                             files: { "batch.csv" => "Hello world" })
  end

  def daily_submission_batch_email_preview
    form = Form.new(build(:v2_form_document, submission_email: "testing@gov.uk"))
    AwsSesSubmissionBatchMailer.daily_submission_batch_email(form:,
                                                             date: Time.zone.now,
                                                             mode: Mode.new("preview-draft"),
                                                             files: { "batch.csv" => "Hello world" })
  end

  def daily_submission_batch_email_with_multiple_files
    form = Form.new(build(:v2_form_document, submission_email: "testing@gov.uk"))
    AwsSesSubmissionBatchMailer.daily_submission_batch_email(form:,
                                                             date: Time.zone.now,
                                                             mode: Mode.new("form"),
                                                             files: {
                                                               "batch.csv" => "Hello world",
                                                               "batch_2.csv" => "Hello again",
                                                             })
  end

  def weekly_submission_batch_email
    form = Form.new(build(:v2_form_document, submission_email: "testing@gov.uk"))
    AwsSesSubmissionBatchMailer.weekly_submission_batch_email(form:,
                                                              begin_date: Time.zone.now - 7.days,
                                                              end_date: Time.zone.now,
                                                              mode: Mode.new("form"),
                                                              files: { "batch.csv" => "Hello world" })
  end

  def weekly_submission_batch_email_preview
    form = Form.new(build(:v2_form_document, submission_email: "testing@gov.uk"))
    AwsSesSubmissionBatchMailer.weekly_submission_batch_email(form:,
                                                              begin_date: Time.zone.now - 7.days,
                                                              end_date: Time.zone.now,
                                                              mode: Mode.new("preview-draft"),
                                                              files: { "batch.csv" => "Hello world" })
  end

  def weekly_submission_batch_email_with_multiple_files
    form = Form.new(build(:v2_question_page_step, submission_email: "testing@gov.uk"))
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
