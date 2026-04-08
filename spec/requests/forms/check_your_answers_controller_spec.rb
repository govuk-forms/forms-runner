require "rails_helper"

RSpec.describe Forms::CheckYourAnswersController, :capture_logging, type: :request do
  include Capybara::RSpecMatchers

  let(:timestamp_of_request) { Time.utc(2022, 12, 14, 10, 0o0, 0o0) }

  let(:form_id) { 2 }
  let(:form_data) do
    build(:v2_form_document, :with_support, :with_submission_email,
          form_id: form_id,
          start_page: 1,
          privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
          what_happens_next_markdown: "Good things come to those that wait",
          declaration_text: "agree to the declaration",
          steps: steps_data,
          support_phone: "0203 222 2222",
          support_email: "help@example.gov.uk",
          support_url: "https://example.gov.uk/help",
          support_url_text: "Get help",
          submission_email:)
  end

  let(:email_confirmation_input) do
    { send_confirmation: "send_email",
      confirmation_email_address: Faker::Internet.email,
      confirmation_email_reference: }
  end

  let(:submission_email) { Faker::Internet.email(domain: "example.gov.uk") }

  let(:store) do
    {
      answers: {
        form_id.to_s => {
          "1" => {
            "date_year" => "2000",
            "date_month" => "1",
            "date_day" => "1",
          },
          "2" => {
            "date_year" => "2023",
            "date_month" => "6",
            "date_day" => "9",
          },
        },
      },
    }
  end

  let(:steps_data) do
    [
      build(:v2_question_step,
            id: 1,
            position: 1,
            next_step_id: 2,
            type: "question",
            answer_type: "date",
            is_optional: nil,
            question_text: "Question one"),
      build(:v2_question_step,
            id: 2,
            position: 2,
            type: "question",
            answer_type: "date",
            is_optional: nil,
            question_text: "Question two"),
    ]
  end

  let(:req_headers) { { "Accept" => "application/json" } }

  let(:api_url_suffix) { "/live" }
  let(:mode) { "form" }

  let(:frozen_time) do
    Time.use_zone("London") { Time.zone.local(2023, 4, 13, 9, 47, 57) }
  end

  let(:repeat_form_submission) { false }

  let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:confirmation_email_id) { "2222" }
  let(:confirmation_email_reference) { "confirmation-email-ref" }

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form_id}#{api_url_suffix}", req_headers, form_data.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      context_spy = original_method.call(form: args[0][:form], store:)
      allow(context_spy).to receive(:form_submitted?).and_return(repeat_form_submission)
      context_spy
    end

    allow(ReferenceNumberService).to receive(:generate).and_return(reference)
    allow(FeatureService).to receive(:enabled?).with("filler_answer_email_enabled").and_return(true)
  end

  describe "#show" do
    shared_examples "for notification references" do
      prepend_before do
        allow(EmailConfirmationInput).to receive(:new).and_wrap_original do |original_method, *args|
          double = original_method.call(*args)
          allow(double).to receive_messages(confirmation_email_reference:)
          double
        end
      end

      it "includes a notification reference for the confirmation email" do
        expect(response.body).to include confirmation_email_reference
      end
    end

    shared_examples "for redirecting if the form is incomplete" do
      context "without any questions answered" do
        let(:store) do
          {
            answers: {},
          }
        end

        it "redirects to first incomplete page of form" do
          get check_your_answers_path(mode:, form_id:, form_slug: form_data.form_slug)
          expect(response).to have_http_status(:found)
          expect(response.location).to eq(form_step_url(mode:, form_id:, form_slug: form_data.form_slug, step_slug: 1))
        end
      end
    end

    shared_examples "check your answers page" do
      it "returns 'ok' status code" do
        expect(response).to have_http_status(:ok)
      end

      it "Displays a back link to the copy of answers page" do
        expect(response.body).to include(copy_of_answers_path(mode:, form_id:, form_slug: form_data.form_slug))
      end

      it "Returns the correct X-Robots-Tag header" do
        expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
      end

      it "contains rows for each question" do
        expect(response.body).to have_css(".govuk-summary-list__key", text: "Question one")
        expect(response.body).to have_css(".govuk-summary-list__value", text: "01/01/2000")
        expect(response.body).to have_css(".govuk-summary-list__key", text: "Question two")
        expect(response.body).to have_css(".govuk-summary-list__value", text: "09/06/2023")
      end
    end

    context "with preview mode on" do
      let(:api_url_suffix) { "/draft" }
      let(:mode) { "preview-draft" }

      include_examples "for redirecting if the form is incomplete"

      context "with all questions answered and valid" do
        before do
          allow(EventLogger).to receive(:log).at_least(:once)
          get check_your_answers_path(mode:, form_id:, form_slug: form_data.form_slug)
        end

        it_behaves_like "check your answers page"

        it "does not log the form_check_answers event" do
          expect(EventLogger).not_to have_received(:log)
        end

        include_examples "for notification references"
      end
    end

    context "with preview mode off" do
      let(:api_url_suffix) { "/live" }
      let(:mode) { "form" }

      include_examples "for redirecting if the form is incomplete"

      context "with all questions answered and valid" do
        before do
          allow(EventLogger).to receive(:log_form_event).at_least(:once)
          get check_your_answers_path(mode:, form_id:, form_slug: form_data.form_slug)
        end

        it_behaves_like "check your answers page"

        it "Logs the form_check_answers event" do
          expect(EventLogger).to have_received(:log_form_event).with("check_answers")
        end

        include_examples "for notification references"
      end
    end
  end

  describe "#submit_answers" do
    before do
      allow_mailer_to_return_mail_with_govuk_notify_response_with(
        FormSubmissionConfirmationMailer,
        :send_confirmation_email,
        id: confirmation_email_id,
      )
    end

    shared_examples "for notification references" do
      it "includes the confirmation_email_reference in the logging_context" do
        expect(log_line["confirmation_email_reference"]).to eq(confirmation_email_reference)
      end
    end

    context "with preview mode on" do
      let(:mode) { "preview-live" }

      before do
        travel_to frozen_time do
          perform_enqueued_jobs do
            post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
          end
        end
      end

      it "redirects to confirmation page" do
        expect(response).to redirect_to(form_submitted_path)
      end

      it "emails the form submission" do
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.length).to eq 2

        mail = deliveries[0]
        expect(mail.to).to eq [submission_email]

        expect(mail.subject).to match("TEST FORM SUBMISSION: #{form_data.name} - reference: #{reference}")
      end

      it "includes the confirmation_email_id in the logging context" do
        expect(log_lines.last["confirmation_email_id"]).to eq(confirmation_email_id)
      end

      include_examples "for notification references"
    end

    context "with preview mode off" do
      let(:mode) { "form" }

      before do
        travel_to frozen_time do
          perform_enqueued_jobs do
            post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
          end
        end
      end

      it "redirects to confirmation page" do
        expect(response).to redirect_to(form_submitted_path)
      end

      it "emails the form submission" do
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.length).to eq 2

        mail = deliveries[0]
        expect(mail.to).to eq [submission_email]

        expect(mail.subject).to match("Form submission: #{form_data.name} - reference: #{reference}")
      end

      it "includes the confirmation_email_id in the logging context" do
        expect(log_lines.last["confirmation_email_id"]).to eq(confirmation_email_id)
      end

      include_examples "for notification references"
    end

    context "when the submission type is s3" do
      let(:form_data) do
        build(:v2_form_document, :s3_submissions_enabled, form_id:, steps: steps_data, start_page: 1)
      end
      let(:mock_credentials) { { foo: "bar" } }
      let(:mock_sts_client) { Aws::STS::Client.new(stub_responses: true) }
      let(:mock_s3_client) { Aws::S3::Client.new(stub_responses: true) }

      before do
        allow(Aws::AssumeRoleCredentials).to receive(:new).and_return(mock_credentials)
        allow(Aws::STS::Client).to receive(:new).and_return(mock_sts_client)
        allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
        allow(mock_s3_client).to receive(:put_object)

        travel_to frozen_time do
          perform_enqueued_jobs do
            post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
          end
        end
      end

      it "redirects to confirmation page" do
        expect(response).to redirect_to(form_submitted_path)
      end

      it "calls put_object with a CSV file and filename" do
        expected_timestamp = "20230413T084757Z"
        expected_key_name = "form_submissions/#{form_id}/#{expected_timestamp}_#{reference}/form_submission.csv"
        expected_csv_content = "Reference,Submitted at,Question one,Question two\n#{reference},2023-04-13T09:47:57+01:00,01/01/2000,09/06/2023\n"
        expect(mock_s3_client).to have_received(:put_object).with(
          {
            body: expected_csv_content,
            bucket: form_data.s3_bucket_name,
            expected_bucket_owner: form_data.s3_bucket_aws_account_id,
            key: expected_key_name,
          },
        )
      end
    end

    context "when answers have already been submitted" do
      let(:repeat_form_submission) { true }

      before do
        post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
      end

      it "redirects to repeat submission error page" do
        expect(response).to redirect_to(error_repeat_submission_path(form_id))
      end
    end

    context "when the form is incomplete" do
      let(:store) do
        {
          answers: {
            form_id.to_s => {
              "1" => {
                "date_year" => "2000",
                "date_month" => "1",
                "date_day" => "1",
              },
            },
          },
        }
      end

      before do
        post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
      end

      it "renders the incomplete submission error page" do
        expect(response).to render_template "errors/incomplete_submission"
      end
    end

    context "when user has not specified whether they want a confirmation email" do
      let(:email_confirmation_input) do
        {
          send_confirmation: nil,
          confirmation_email_reference:,
        }
      end

      before do
        post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
      end

      it "return 422 error code" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders the check your answers page" do
        expect(response).to render_template("forms/check_your_answers/show")
      end

      it "does not generate a new submission reference" do
        expect(response.body).to include confirmation_email_reference
      end
    end

    context "when user has not specified the confirmation email address" do
      let(:email_confirmation_input) do
        {
          send_confirmation: "send_email",
          confirmation_email_address: nil,
          confirmation_email_reference:,
        }
      end

      before do
        post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
      end

      it "return 422 error code" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders the check your answers page" do
        expect(response).to render_template("forms/check_your_answers/show")
      end

      it "does not generate a new submission reference" do
        expect(response.body).to include confirmation_email_reference
      end

      include_examples "for notification references"
    end

    context "when user has not requested a confirmation email" do
      let(:email_confirmation_input) do
        {
          send_confirmation: "skip_confirmation",
          confirmation_email_address: nil,
          confirmation_email_reference:,
        }
      end

      before do
        post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
      end

      it "redirects to confirmation page" do
        expect(response).to redirect_to(form_submitted_path)
      end

      it "does not include the confirmation_email_id in the logging context" do
        expect(log_line.keys).not_to include("confirmation_email_id")
      end

      it "does not include confirmation_email_reference in logging context" do
        expect(log_line.keys).not_to include("confirmation_email_reference")
      end
    end

    context "when user has requested a confirmation email" do
      let(:email_confirmation_input) do
        { send_confirmation: "send_email",
          confirmation_email_address: Faker::Internet.email,
          confirmation_email_reference: }
      end

      before do
        travel_to timestamp_of_request do
          perform_enqueued_jobs do
            post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
          end
        end
      end

      it "redirects to confirmation page" do
        expect(response).to redirect_to(form_submitted_path)
      end

      it "sends a confirmation email" do
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.length).to eq 2

        mail = deliveries[1]
        expect(mail.to).to eq([email_confirmation_input[:confirmation_email_address]])

        expected_personalisation = {
          title: form_data.name,
          what_happens_next_text: form_data.what_happens_next_markdown,
          support_contact_details: contact_support_details_format,
          submission_time: "10:00am",
          submission_date: "14 December 2022",
          test: "no",
          submission_reference: reference,
          include_payment_link: "no",
          payment_link: "",
        }

        expect(mail.body.raw_source).to include(expected_personalisation.to_s)

        expect(mail.govuk_notify_reference).to eq confirmation_email_reference
      end

      it "includes the confirmation_email_id in the logging context" do
        expect(log_lines.last["confirmation_email_id"]).to eq(confirmation_email_id)
      end

      include_examples "for notification references"
    end

    context "when there is a submission error" do
      let(:email_confirmation_input) do
        { send_confirmation: "send_email",
          confirmation_email_address: Faker::Internet.email,
          confirmation_email_reference: }
      end

      before do
        allow(FormSubmissionService).to receive(:call).and_raise(StandardError)
        allow(Sentry).to receive(:capture_exception)

        travel_to timestamp_of_request do
          post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
        end
      end

      it "calls Sentry" do
        expect(Sentry).to have_received(:capture_exception)
      end

      it "renders the submission_error template" do
        expect(response).to render_template("errors/submission_error")
      end

      it "returns 500" do
        expect(response).to have_http_status(:internal_server_error)
      end

      include_examples "for notification references"
    end

    context "when there is an ActionMailer error with the confirmation email address" do
      before do
        mock_form_submission_service = instance_double(FormSubmissionService)
        allow(FormSubmissionService).to receive(:new).and_return(mock_form_submission_service)
        allow(mock_form_submission_service).to receive(:submit).and_raise(FormSubmissionService::ConfirmationEmailToAddressError)

        post form_submit_answers_path(form_id:, form_slug: "form-name", mode:), params: { email_confirmation_input: }
      end

      it "return 422 error code" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders the check your answers page" do
        expect(response).to render_template("forms/check_your_answers/show")
      end

      it "has a validation error for the confirmation email address" do
        expect(response.body).to include(I18n.t("activemodel.errors.models.email_confirmation_input.attributes.confirmation_email_address.invalid_email"))
      end
    end
  end

private

  def contact_support_details_format
    phone_number = "#{form_data.support_phone}\n\n[#{I18n.t('support_details.call_charges')}](https://www.gov.uk/call-charges)"
    email = "[#{form_data.support_email}](mailto:#{form_data.support_email})"
    online = "[#{form_data.support_url_text}](#{form_data.support_url})"
    [phone_number, email, online].compact_blank.join("\n\n")
  end
end
