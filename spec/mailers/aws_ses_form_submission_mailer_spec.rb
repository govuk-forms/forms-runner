require "rails_helper"

describe AwsSesFormSubmissionMailer, type: :mailer do
  subject(:mail) { described_class.submission_email(submission:, files:, csv_filename:, json_filename:) }

  let(:submission) do
    build(:submission, form_document: form_document, created_at: submission_timestamp,
                       reference: submission_reference, is_preview:, submission_locale:)
  end
  let(:form_document) { build(:v2_form_document, name: form_name, submission_email: submission_email_address, payment_url:) }
  let(:form_name) { "Form 1" }
  let(:is_preview) { false }
  let(:submission_email_address) { "testing@gov.uk" }
  let(:files) { {} }
  let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:payment_url) { nil }
  let(:csv_filename) { nil }
  let(:json_filename) { nil }
  let(:submission_timestamp) { Time.utc(2022, 12, 14, 13, 0o0, 0o0) }
  let(:submission_locale) { :en }

  let(:journey) { instance_double(Flow::Journey, completed_steps: [step]) }
  let(:question) { build :text, question_text: "What is the meaning of life?", text: "The meaning of life is 42" }
  let(:step) { build :step, question: }

  before do
    allow(Flow::Journey).to receive(:new).and_return(journey)
  end

  context "when form filler submits a completed form" do
    context "when form is not in preview" do
      it "sends an email to the form's submission email address" do
        expect(mail.to).to eq([submission_email_address])
      end

      it "sets the subject" do
        expect(mail.subject).to eq("Form submission: #{form_name} - reference: #{submission_reference}")
      end

      describe "the html part" do
        let(:part) { mail.html_part }

        it "has the email subject as its title" do
          expect(part.body).to have_title(mail.subject)
        end

        it "has a link to GOV.UK" do
          expect(part.body).to have_link("GOV.UK", href: "https://www.gov.uk")
        end

        it "includes the answers" do
          expect(part.body).to have_css("h3", text: "What is the meaning of life?")
          expect(part.body).to have_css("p", text: "The meaning of life is 42")
        end

        it "includes the form title text" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.form_name", form_name: form_name))
        end

        it "does not include the form preview text" do
          expect(part.body).not_to have_css("p", text: I18n.t("mailer.submission.preview"))
        end

        it "includes text about the submission time" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.submission.time", time: submission_timestamp.strftime("%l:%M%P").strip, date: submission_timestamp.strftime("%-d %B %Y")))
        end

        it "includes the submission reference" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.submission.reference", submission_reference:))
        end

        it "includes text about checking the answers" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.check_before_using"))
        end

        it "includes the answers submitted heading" do
          expect(part.body).to have_css("h2", text: I18n.t("mailer.submission.answers_submitted"))
        end

        it "includes the warning about not replying" do
          expect(part.body).to have_css("h2", text: I18n.t("mailer.cannot_reply.heading"))
          expect(part.body).to include(GovukFormsMarkdown.render_for_email(I18n.t("mailer.cannot_reply.contact_form_filler_markdown")))
          expect(part.body).to include(GovukFormsMarkdown.render_for_email(I18n.t("mailer.cannot_reply.contact_forms_team_markdown")))
        end

        describe "submission date/time" do
          context "with a time in BST" do
            let(:submission_timestamp) { Time.utc(2022, 9, 14, 8, 0o0, 0o0).in_time_zone(submission_timezone) }

            it "includes the date and time the user submitted the form" do
              expect(part.body).to match("Submitted at: 9:00am on 14 September 2022")
            end
          end

          context "with a time in GMT" do
            let(:submission_timestamp) { Time.utc(2022, 12, 14, 13, 0o0, 0o0).in_time_zone(submission_timezone) }

            it "includes the date and time the user submitted the form" do
              expect(part.body).to match("Submitted at: 1:00pm on 14 December 2022")
            end
          end
        end

        describe "submission_locale" do
          context "with a submission in English" do
            it "does not include the Welsh submission text" do
              expect(part.body).not_to match("Welsh")
            end
          end

          context "with a submission in Welsh" do
            let(:submission_locale) { :cy }

            it "includes the Welsh submission text" do
              expect(part.body).to match("Welsh")
            end

            it "uses the English question text" do
              expect(part.body).to have_css("h3", text: "What is the meaning of life?")
            end
          end
        end
      end

      describe "the plaintext part" do
        let(:part) { mail.text_part }

        it "includes the answers" do
          expect(part.body).to match("What is the meaning of life?")
          expect(part.body).to match("The meaning of life is 42")
        end

        it "includes the form title text" do
          expect(part.body).to have_text(I18n.t("mailer.form_name", form_name: form_name))
        end

        it "does not include the form preview text" do
          expect(part.body).not_to have_text(I18n.t("mailer.submission.preview"))
        end

        it "includes text about the submission time" do
          expect(part.body).to have_text(I18n.t("mailer.submission.time", time: submission_timestamp.strftime("%l:%M%P").strip, date: submission_timestamp.strftime("%-d %B %Y")))
        end

        it "includes the submission reference" do
          expect(part.body).to have_text(I18n.t("mailer.submission.reference", submission_reference:))
        end

        it "includes text about checking the answers" do
          expect(part.body).to have_text(I18n.t("mailer.check_before_using"))
        end

        it "includes the answers submitted heading" do
          expect(part.body).to have_text(I18n.t("mailer.submission.answers_submitted"))
        end

        it "includes the warning about not replying" do
          expect(part.body).to have_text(I18n.t("mailer.cannot_reply.heading"))
          expect(part.body).to include(GovukFormsMarkdown.render_plain_text(I18n.t("mailer.cannot_reply.contact_form_filler_markdown")))
          expect(part.body).to include(GovukFormsMarkdown.render_plain_text(I18n.t("mailer.cannot_reply.contact_forms_team_markdown")))
        end

        describe "submission date/time" do
          context "with a time in BST" do
            let(:submission_timestamp) { Time.utc(2022, 9, 14, 8, 0o0, 0o0).in_time_zone(submission_timezone) }

            it "includes the date and time the user submitted the form" do
              expect(part.body).to match("Submitted at: 9:00am on 14 September 2022")
            end
          end

          context "with a time in GMT" do
            let(:submission_timestamp) { Time.utc(2022, 12, 14, 13, 0o0, 0o0).in_time_zone(submission_timezone) }

            it "includes the date and time the user submitted the form" do
              expect(part.body).to match("Submitted at: 1:00pm on 14 December 2022")
            end
          end
        end

        describe "submission_locale" do
          context "with a submission in English" do
            it "does not include the Welsh submission text" do
              expect(part.body).not_to match("Welsh")
            end
          end

          context "with a submission in Welsh" do
            let(:submission_locale) { :cy }

            it "includes the Welsh submission text" do
              expect(part.body).to match("Welsh")
            end
          end
        end
      end
    end

    context "when form is in preview" do
      let(:is_preview) { true }

      it "sets the subject" do
        expect(mail.subject).to eq("TEST FORM SUBMISSION: #{form_name} - reference: #{submission_reference}")
      end

      describe "the html part" do
        let(:part) { mail.html_part }

        it "includes the form title text" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.form_name", form_name: form_name))
        end

        it "includes the form preview text" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.submission.preview"))
        end
      end

      describe "the plaintext part" do
        let(:part) { mail.text_part }

        it "includes the form title text" do
          expect(part.body).to have_text(I18n.t("mailer.form_name", form_name: form_name))
        end

        it "includes the form preview text" do
          expect(part.body).to have_text(I18n.t("mailer.submission.preview"))
        end
      end
    end

    context "when the form has a payment link" do
      let(:payment_url) { "payment_url" }

      describe "the html part" do
        let(:part) { mail.html_part }

        it "includes text about the payment" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.submission.payment"))
        end
      end

      describe "the plaintext part" do
        let(:part) { mail.text_part }

        it "includes text about the payment" do
          expect(part.body).to have_text(I18n.t("mailer.submission.payment"))
        end
      end
    end

    context "when the form does not have a payment link" do
      describe "the html part" do
        let(:part) { mail.html_part }

        it "does not include text about the payment" do
          expect(part.body).not_to have_css("p", text: I18n.t("mailer.submission.payment"))
        end
      end

      describe "the plaintext part" do
        let(:part) { mail.text_part }

        it "does not include text about the payment" do
          expect(part.body).not_to have_text(I18n.t("mailer.submission.payment"))
        end
      end
    end

    context "when the csv file of answers is attached" do
      let(:csv_filename) { "my_answers.csv" }

      describe "the html part" do
        let(:part) { mail.html_part }

        it "includes text about the CSV filename" do
          expect(part.body).to have_css("p", text: I18n.t("mailer.submission.csv_file", filename: csv_filename))
        end
      end

      describe "the plaintext part" do
        let(:part) { mail.text_part }

        it "includes text about the CSV filename" do
          expect(part.body).to have_text(I18n.t("mailer.submission.csv_file", filename: csv_filename))
        end
      end
    end

    context "when the csv file of answers is not attached" do
      describe "the html part" do
        let(:part) { mail.html_part }

        it "does not include text about the CSV filename" do
          expect(part.body).not_to have_css("p", text: I18n.t("mailer.submission.csv_file", filename: csv_filename))
        end
      end

      describe "the plaintext part" do
        let(:part) { mail.text_part }

        it "does not include text about the CSV filename" do
          expect(part.body).not_to have_text(I18n.t("mailer.submission.csv_file", filename: csv_filename))
        end
      end

      context "when the json file of answers is attached" do
        let(:json_filename) { "my_answers.json" }

        describe "the html part" do
          let(:part) { mail.html_part }

          it "includes text about the JSON filename" do
            expect(part.body).to have_css("p", text: I18n.t("mailer.submission.json_file", filename: json_filename))
          end
        end

        describe "the plaintext part" do
          let(:part) { mail.text_part }

          it "includes text about the JSON filename" do
            expect(part.body).to have_text(I18n.t("mailer.submission.json_file", filename: json_filename))
          end
        end
      end
    end
  end

  context "when files to attach are included in the arguments" do
    let(:csv_file_name) { "first-file.csv" }
    let(:png_file_name) { "second-file.png" }
    let(:files) do
      {
        csv_file_name => Faker::Lorem.sentence,
        png_file_name => Faker::Lorem.sentence,
      }
    end

    it "has 2 attachments" do
      expect(mail.attachments.size).to eq(2)
    end

    it "has the files attached with expected filenames" do
      expect(mail.attachments[0].filename).to eq(csv_file_name)
      expect(mail.attachments[1].filename).to eq(png_file_name)
    end

    it "has the files attached with expected content" do
      expect(mail.attachments[0].body).to eq(files[csv_file_name])
      expect(mail.attachments[1].body).to eq(files[png_file_name])
    end
  end

private

  def submission_timezone
    Rails.configuration.x.submission.time_zone || "UTC"
  end
end
