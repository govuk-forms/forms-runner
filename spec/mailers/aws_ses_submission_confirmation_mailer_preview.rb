class AwsSesSubmissionConfirmationMailerPreview < ActionMailer::Preview
  include FactoryBot::Syntax::Methods

  def english_only
    submission = build(:submission, form_document: form_document, answers: answers, is_preview: false)

    AwsSesSubmissionConfirmationMailer.submission_confirmation_email(
      submission:,
      confirmation_email_address: "foo@example.com",
      include_copy_of_answers: true,
    )
  end

  def with_welsh
    submission = build(:submission,
                       form_document: form_document,
                       welsh_form_document: welsh_form_document,
                       answers: answers,
                       is_preview: false,
                       submission_locale: "cy")

    AwsSesSubmissionConfirmationMailer.submission_confirmation_email(
      submission:,
      confirmation_email_address: "foo@example.com",
      include_copy_of_answers: true,
    )
  end

  def without_copy_of_answers
    submission = build(:submission, form_document: form_document, is_preview: false)

    AwsSesSubmissionConfirmationMailer.submission_confirmation_email(
      submission:,
      confirmation_email_address: "foo@example.com",
      include_copy_of_answers: false,
    )
  end

  def test_submission
    submission = build(:submission,
                       form_document: form_document,
                       welsh_form_document: welsh_form_document,
                       is_preview: true,
                       submission_locale: "cy")

    AwsSesSubmissionConfirmationMailer.submission_confirmation_email(
      submission:,
      confirmation_email_address: "foo@example.com",
      include_copy_of_answers: false,
    )
  end

  def without_what_happens_next_and_support_contact_details_and_payment_link
    form_document = build(:v2_form_document,
                          payment_url: nil,
                          what_happens_next_markdown: nil,
                          support_phone: nil,
                          support_email: nil,
                          support_url: nil,
                          support_url_text: nil)
    submission = build(:submission, form_document:, is_preview: false)

    AwsSesSubmissionConfirmationMailer.submission_confirmation_email(
      submission:,
      confirmation_email_address: "foo@example.com",
      include_copy_of_answers: false,
    )
  end

private

  def form_document
    steps = [
      build(:v2_question_step, :with_text_settings, id: "a1", next_step_id: "a2"),
      build(:v2_question_step, :with_name_settings, id: "a2", next_step_id: "a3"),
      build(:v2_question_step, :with_file_upload_settings, id: "a3"),
    ]
    build(:v2_form_document,
          steps: steps,
          start_page: "a1",
          name: "English form",
          payment_url: "https://www.gov.uk/payments/test-service/pay-for-licence?reference=W38SFV3S",
          what_happens_next_markdown: "Some text about what happens next\n\n- With a list\n- Of things\n- To do\n[A link](https://wwww.link.example.com)",
          support_phone: "0203 222 2222\r\nLines are open 8am - 6pm Monday to Friday",
          support_email: "help@example.gov.uk",
          support_url: "https://example.gov.uk/help",
          support_url_text: "Get help")
  end

  def welsh_form_document
    welsh_steps = [
      build(:v2_question_step, :with_text_settings, question_text: "Welsh text", id: "a1", next_step_id: "a2"),
      build(:v2_question_step, :with_name_settings, question_text: "Welsh name", id: "a2", next_step_id: "a3"),
      build(:v2_question_step, :with_file_upload_settings, question_text: "Welsh file upload", id: "a3"),
    ]
    build(:v2_form_document,
          steps: welsh_steps,
          start_page: "a1",
          name: "Welsh Form",
          payment_url: "https://www.gov.wales/payments/test-service/pay-for-licence?reference=W38SFV3S",
          what_happens_next_markdown: "Rhywfaint o destun am yr hyn sy'n digwydd nesaf\n\n- Gyda rhestr\n- O bethau\n- I'w gwneud",
          support_phone: "0203 333 3333\r\nMae'r llinellau ar agor 8am - 6pm o ddydd Llun i ddydd Gwener",
          support_email: "help@example.gov.wales",
          support_url: "https://example.gov.wales/help",
          support_url_text: "Cael help")
  end

  def answers
    {
      "a1" => { text: "First answer/nSecond line of first answer" },
      "a2" => { first_name: "Joe", last_name: "Bloggs" },
      "a3" => { original_filename: "test.txt" },
    }
  end
end
