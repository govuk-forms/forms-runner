class AwsSesFormSubmissionMailerPreview < ActionMailer::Preview
  include FactoryBot::Syntax::Methods

  def submission_email
    form_document = build(:v2_form_document, steps:, start_page: "a1", submission_email: "testing@gov.uk")
    submission = build(:submission, form_document:, answers:, is_preview: false)
    AwsSesFormSubmissionMailer.submission_email(submission:,
                                                files: {})
  end

  def preview_submission_email
    form_document = build(:v2_form_document, steps:, start_page: "a1", submission_email: "testing@gov.uk")
    submission = build(:submission, form_document:, answers:, is_preview: true)
    AwsSesFormSubmissionMailer.submission_email(submission:,
                                                files: {})
  end

  def submission_email_with_payment_link
    form_document = build(:v2_form_document, steps:, start_page: "a1", submission_email: "testing@gov.uk", payment_url: "https://www.gov.uk/payments/your-payment-link")
    submission = build(:submission, form_document:, answers:, is_preview: false)
    AwsSesFormSubmissionMailer.submission_email(submission:,
                                                files: {})
  end

  def submission_email_with_welsh
    form_document = build(:v2_form_document, steps:, start_page: "a1", submission_email: "testing@gov.uk", payment_url: "https://www.gov.uk/payments/your-payment-link")
    submission = build(:submission, form_document:, answers:, is_preview: false, submission_locale: :cy)
    AwsSesFormSubmissionMailer.submission_email(submission:,
                                                files: {})
  end

  def submission_email_with_csv
    form_document = build(:v2_form_document, steps:, start_page: "a1", submission_email: "testing@gov.uk", payment_url: "https://www.gov.uk/payments/your-payment-link")
    submission = build(:submission, form_document:, answers:, is_preview: false)
    AwsSesFormSubmissionMailer.submission_email(submission:,
                                                files: {},
                                                csv_filename: "my_answers.csv")
  end

  def submission_email_with_json
    form_document = build(:v2_form_document, steps:, start_page: "a1", submission_email: "testing@gov.uk", payment_url: "https://www.gov.uk/payments/your-payment-link")
    submission = build(:submission, form_document:, answers:, is_preview: false)
    AwsSesFormSubmissionMailer.submission_email(submission:,
                                                files: {},
                                                json_filename: "my_answers.json")
  end

  def submission_email_with_csv_and_json
    form_document = build(:v2_form_document, steps:, start_page: "a1", submission_email: "testing@gov.uk", payment_url: "https://www.gov.uk/payments/your-payment-link")
    submission = build(:submission, form_document:, answers:, is_preview: false)
    AwsSesFormSubmissionMailer.submission_email(submission:,
                                                files: {},
                                                csv_filename: "my_answers.csv",
                                                json_filename: "my_answers.json")
  end

private

  def steps
    [
      build(:v2_question_step, :with_text_settings, id: "a1", next_step_id: "a2"),
      build(:v2_question_step, :with_name_settings, id: "a2"),
    ]
  end

  def answers
    {
      "a1" => { text: "First answer\nSecond line of first answer" },
      "a2" => { first_name: "Joe", last_name: "Bloggs" },
    }
  end
end
