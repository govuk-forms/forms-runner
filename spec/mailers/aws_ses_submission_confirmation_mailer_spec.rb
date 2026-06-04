require "rails_helper"

RSpec.describe AwsSesSubmissionConfirmationMailer, type: :mailer do
  subject(:mail) do
    described_class.submission_confirmation_email(
      submission: submission,
      confirmation_email_address: confirmation_email_address,
      include_copy_of_answers: include_copy_of_answers,
    )
  end

  let(:confirmation_email_address) { "testing@example.gov.uk" }
  let(:include_copy_of_answers) { true }
  let(:welsh_form) { Form.new(welsh_form_document) if welsh_form_document }
  let(:welsh_form_document) { nil }
  let(:submission_locale) { "en" }
  let(:is_preview) { false }
  let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:submission_timestamp) { Time.zone.now }
  let(:submission) do
    build(:submission,
          form_document:,
          welsh_form_document:,
          created_at: submission_timestamp,
          reference: submission_reference,
          submission_locale:,
          answers:,
          is_preview:)
  end
  let(:answers) { { "q1" => { text: "blue" }, "q2" => { first_name: "Jane", last_name: "Doe" }, "q3" => { original_filename: "test.txt" } } }
  let(:what_happens_next_markdown) { "Please wait for a response\nA list:\n\n- Item one\n- Item two" }
  let(:payment_url) { "https://pay.example.gov" }
  let(:form_document) do
    build(:v2_form_document,
          name: "My form",
          steps: [
            build(:v2_question_step, :with_text_settings, question_text: "What is your favourite colour?", id: "q1", next_step_id: "q2"),
            build(:v2_question_step, :with_name_settings, question_text: "What is your name?", id: "q2", next_step_id: "q3"),
            build(:v2_question_step, :with_file_upload_settings, question_text: "Upload a file", id: "q3"),
          ],
          start_page: "q1",
          payment_url:,
          what_happens_next_markdown:,
          support_phone: "0203 222 2222",
          support_email: "help@example.gov.uk",
          support_url: "https://example.gov.uk/help",
          support_url_text: "Get help")
  end

  context "when optional content is present" do
    it "sends to the requested address" do
      expect(mail.to).to eq([confirmation_email_address])
    end

    it "has the expected subject" do
      expect(mail.subject).to eq(I18n.t("mailer.submission_confirmation.subject", reference: submission_reference))
    end

    describe "the text part" do
      let(:part) { mail.text_part }

      it "includes the what happens next text formatted as plain text from the markdown" do
        expect(part.body).to include("Please wait for a response\nA list:\n• Item one\n• Item two")
      end

      it "includes the payment link with the reference" do
        expect(part.body).to include(I18n.t("mailer.submission_confirmation.payment_link_heading"))
        expect(part.body).to include("#{form_document.payment_url}?reference=#{submission_reference}")
      end

      it "includes support contact details" do
        expect(part.body).to include("0203 222 2222")
        expect(part.body).to include("help@example.gov.uk")
        expect(part.body).to include("Get help: https://example.gov.uk/help")
      end

      it "includes the answers content" do
        expect(part.body).to include("What is your favourite colour?")
        expect(part.body).to include("blue")
        expect(part.body).to include("What is your name?")
        expect(part.body).to include("First name: Jane")
        expect(part.body).to include("Last name: Doe")
        expect(part.body).to include("Upload a file")
        expect(part.body).to include(I18n.t("mailer.submission_confirmation.file_answer", filename: "test.txt"))
      end
    end

    describe "the html part" do
      let(:part) { mail.html_part }

      it "includes the what happens next formatted as html from the markdown" do
        expect(part.body).to have_css("p", text: "Please wait for a response")
        expect(part.body).to have_css("p", text: "A list:")
        expect(part.body).to have_css("ul li", text: "Item one")
        expect(part.body).to have_css("ul li", text: "Item two")
      end

      it "includes the payment link with the reference" do
        expect(part.body).to have_css("h3", text: I18n.t("mailer.submission_confirmation.payment_link_heading"))
        expect(part.body).to have_link("#{form_document.payment_url}?reference=#{submission_reference}")
      end

      it "includes support contact details" do
        expect(part.body).to have_text("0203 222 2222")
        expect(part.body).to have_link("help@example.gov.uk", href: "mailto:help@example.gov.uk")
        expect(part.body).to have_link("Get help", href: "https://example.gov.uk/help")
      end

      it "includes the question headings and answers" do
        expect(part.body).to have_css("h4", text: "What is your favourite colour?")
        expect(part.body).to have_text("blue")
        expect(part.body).to have_css("h4", text: "What is your name?")
        expect(part.body).to have_text("First name: Jane")
        expect(part.body).to have_text("Last name: Doe")
        expect(part.body).to have_css("h4", text: "Upload a file")
        expect(part.body).to have_text(I18n.t("mailer.submission_confirmation.file_answer", filename: "test.txt"))
      end
    end
  end

  context "when the submission is a preview" do
    let(:is_preview) { true }

    it "has the subject for a preview submission" do
      expect(mail.subject).to eq(I18n.t("mailer.submission_confirmation.subject_preview", reference: submission_reference))
    end

    it "has content for a preview submission in the text part" do
      expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.title_preview"))
      expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.this_is_a_test"))
    end

    it "has the content for a preview submission in the html part" do
      expect(mail.html_part.body).to have_css("h2", text: I18n.t("mailer.submission_confirmation.title_preview"))
      expect(mail.html_part.body).to have_css("p", text: I18n.t("mailer.submission_confirmation.this_is_a_test"))
    end
  end

  context "when the what happens next markdown is not set" do
    let(:what_happens_next_markdown) { nil }

    it "falls back to default what happens next text for the text part" do
      expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.default_what_happens_next"))
    end

    it "falls back to default what happens next html" do
      expect(mail.html_part.body).to have_text(I18n.t("mailer.submission_confirmation.default_what_happens_next"))
    end
  end

  context "when the support details are not set" do
    let(:part) { mail.text_part }

    let(:form_document) do
      build(:v2_form_document,
            name: "My form",
            support_phone: nil,
            support_email: nil,
            support_url: nil,
            support_url_text: nil)
    end
    let(:include_copy_of_answers) { false }

    it "renders the default support contact details text for the text part" do
      expect(part.body).to include(I18n.t("mailer.submission_confirmation.contact_details_heading"))
      expect(part.body).to include(I18n.t("mailer.submission_confirmation.default_support_contact_details"))
    end

    it "renders the default support contact details html" do
      expect(mail.html_part.body).to have_text(I18n.t("mailer.submission_confirmation.contact_details_heading"))
      expect(mail.html_part.body).to have_text(I18n.t("mailer.submission_confirmation.default_support_contact_details"))
    end
  end

  context "when the payment url is not set" do
    let(:payment_url) { nil }

    it "does not include the payment link heading for the text part" do
      expect(mail.text_part.body).not_to include(I18n.t("mailer.submission_confirmation.payment_link_heading"))
    end

    it "does not include the payment link html" do
      expect(mail.html_part.body).not_to include(I18n.t("mailer.submission_confirmation.payment_link_heading"))
    end
  end

  context "when include_copy_of_answers is false" do
    let(:include_copy_of_answers) { false }

    it "does not include the answers content for the text part" do
      expect(mail.text_part.body).not_to include(I18n.t("mailer.submission_confirmation.answers_submitted_heading"))
      expect(mail.text_part.body).not_to include("What is your name?")
    end

    it "does not include the answers content for the html part" do
      expect(mail.html_part.body).not_to include("What is your name?")
    end
  end

  context "when submission_locale is Welsh" do
    let(:welsh_form_document) do
      build(:v2_form_document,
            name: "Welsh form",
            steps: [
              build(:v2_question_step, :with_text_settings, question_text: "Beth yw eich hoff liw?", id: "q1", next_step_id: "q2"),
              build(:v2_question_step, :with_name_settings, question_text: "Beth yw dy enw?", id: "q2", next_step_id: "q3"),
              build(:v2_question_step, :with_file_upload_settings, question_text: "Llwythwch ffeil i fyny", id: "q3"),
            ],
            start_page: "q1",
            what_happens_next_markdown: "Arhoswch am ymateb\nRhestr:\n\n- Eitem un\n- Eitem dau",
            support_phone: "02920 111 222",
            support_email: "help-cy@example.gov.uk",
            support_url: "https://example.gov.uk/help-cy",
            support_url_text: "Cael cymorth",
            payment_url: "https://pay.example.gov.uk/cy")
    end
    let(:submission_locale) { "cy" }

    it "includes the Welsh in the subject" do
      english = I18n.t("mailer.submission_confirmation.subject", reference: submission_reference)
      welsh = I18n.t("mailer.submission_confirmation.subject", reference: submission_reference, locale: :cy)
      expect(mail.subject).to eq("#{english} | #{welsh}")
    end

    context "when the submission is a preview" do
      let(:is_preview) { true }

      it "has the subject for a preview including the Welsh" do
        english = I18n.t("mailer.submission_confirmation.subject_preview", reference: submission_reference)
        welsh = I18n.t("mailer.submission_confirmation.subject", reference: submission_reference, locale: :cy)
        expect(mail.subject).to eq("#{english} | #{welsh}")
      end

      it "has content for a preview submission in both English and Welsh in the text part" do
        expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.title_preview"))
        expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.this_is_a_test"))
        expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.title_preview", locale: :cy))
        expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.this_is_a_test", locale: :cy))
      end

      it "has the content for a preview submission in both English and Welsh in the html part" do
        expect(mail.html_part.body).to have_css("h2", text: I18n.t("mailer.submission_confirmation.title_preview"))
        expect(mail.html_part.body).to have_css("p", text: I18n.t("mailer.submission_confirmation.this_is_a_test"))
        expect(mail.html_part.body).to have_css("h2", text: I18n.t("mailer.submission_confirmation.title_preview", locale: :cy))
        expect(mail.html_part.body).to have_css("p", text: I18n.t("mailer.submission_confirmation.this_is_a_test", locale: :cy))
      end
    end

    describe "the text part" do
      let(:part) { mail.text_part }

      it "includes the English and Welsh what happens next" do
        expect(part.body).to include("Please wait for a response\nA list:\n• Item one\n• Item two")
        expect(part.body).to have_text("Arhoswch am ymateb\nRhestr:\n• Eitem un\n• Eitem dau")
      end

      it "includes both the English and Welsh contact details" do
        expect(part.body).to include("0203 222 2222")
        expect(part.body).to include("help@example.gov.uk")
        expect(part.body).to include("Get help: https://example.gov.uk/help")

        expect(part.body).to include("02920 111 222")
        expect(part.body).to include("help-cy@example.gov.uk")
        expect(part.body).to include("Cael cymorth: https://example.gov.uk/help-cy")
      end

      it "includes both the English and Welsh payment URLs" do
        expect(part.body).to include(I18n.t("mailer.submission_confirmation.payment_link_heading"))
        expect(part.body).to include("https://pay.example.gov?reference=#{submission_reference}")

        expect(part.body).to include(I18n.t("mailer.submission_confirmation.payment_link_heading", locale: :cy))
        expect(part.body).to include("https://pay.example.gov.uk/cy?reference=#{submission_reference}")
      end

      it "includes the English and Welsh answers" do
        expect(part.body).to include("What is your favourite colour?")
        expect(part.body).to include("What is your name?")
        expect(part.body).to include("Upload a file")
        expect(part.body).to include(I18n.t("mailer.submission_confirmation.file_answer", filename: "test.txt"))

        expect(part.body).to include("Beth yw eich hoff liw?")
        expect(part.body).to include("Beth yw dy enw?")
        expect(part.body).to include("Llwythwch ffeil i fyny")
        expect(part.body).to include(I18n.t("mailer.submission_confirmation.file_answer", filename: "test.txt", locale: :cy))
      end
    end

    describe "the html part" do
      let(:part) { mail.html_part }

      it "includes the English and Welsh what happens next" do
        expect(part.body).to have_css("p", text: "Please wait for a response")
        expect(part.body).to have_css("p", text: "A list:")
        expect(part.body).to have_css("ul li", text: "Item one")
        expect(part.body).to have_css("ul li", text: "Item two")
        expect(part.body).to have_css("p", text: "Arhoswch am ymateb")
        expect(part.body).to have_css("p", text: "Rhestr:")
        expect(part.body).to have_css("ul li", text: "Eitem un")
        expect(part.body).to have_css("ul li", text: "Eitem dau")
      end

      it "includes both the English and Welsh contact details" do
        expect(part.body).to have_text("0203 222 2222")
        expect(part.body).to have_link("help@example.gov.uk", href: "mailto:help@example.gov.uk")
        expect(part.body).to have_link("Get help", href: "https://example.gov.uk/help")

        expect(part.body).to have_text("02920 111 222")
        expect(part.body).to have_link("help-cy@example.gov.uk", href: "mailto:help-cy@example.gov.uk")
        expect(part.body).to have_link("Cael cymorth", href: "https://example.gov.uk/help-cy")
      end

      it "includes both the English and Welsh payment URLs" do
        expect(part.body).to have_css("h3", text: I18n.t("mailer.submission_confirmation.payment_link_heading"))
        expect(part.body).to have_link("https://pay.example.gov?reference=#{submission_reference}")

        expect(part.body).to have_css("h3", text: I18n.t("mailer.submission_confirmation.payment_link_heading", locale: :cy))
        expect(part.body).to have_link("https://pay.example.gov.uk/cy?reference=#{submission_reference}")
      end

      it "includes the English and Welsh answers" do
        expect(part.body).to have_css("h4", text: "What is your favourite colour?")
        expect(part.body).to have_css("h4", text: "What is your name?")
        expect(part.body).to have_css("h4", text: "Upload a file")
        expect(part.body).to have_text(I18n.t("mailer.submission_confirmation.file_answer", filename: "test.txt"))

        expect(part.body).to have_css("h4", text: "Beth yw eich hoff liw?")
        expect(part.body).to have_css("h4", text: "Beth yw dy enw?")
        expect(part.body).to have_css("h4", text: "Llwythwch ffeil i fyny")
        expect(part.body).to have_text(I18n.t("mailer.submission_confirmation.file_answer", filename: "test.txt", locale: :cy))
      end
    end
  end
end
