require "rails_helper"

RSpec.describe Forms::BaseController, type: :request do
  let(:timestamp_of_request) { Time.utc(2022, 12, 14, 10, 0o0, 0o0) }

  let(:form_response_data) do
    build(
      :v2_form_document,
      :with_support,
      form_id: 2,
      start_page:,
      privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
      what_happens_next_markdown: "Good things come to those that wait",
      declaration_text: "agree to the declaration",
      steps: steps_data,
      language:,
    )
  end
  let(:start_page) { 1 }
  let(:language) { "en" }

  let(:no_data_found_response) do
    {
      "error": "not_found",
    }
  end

  let(:steps_data) do
    [
      (attributes_for :v2_question_step,
                      id: 1,
                      next_page: 2,
                      answer_type: "text",
                      answer_settings: { input_type: "single_line" }
      ),
      (attributes_for :v2_question_step,
                      id: 2,
                      answer_type: "text",
                      answer_settings: { input_type: "single_line" }
      ),
    ]
  end

  let(:req_headers) { { "Accept" => "application/json" } }

  let(:api_url_suffix) { "/live" }

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/2#{api_url_suffix}", req_headers, form_response_data.to_json, 200
      mock.get "/api/v2/forms/2#{api_url_suffix}?language=cy", req_headers, form_response_data.to_json, 200
      mock.get "/api/v2/forms/9999#{api_url_suffix}", req_headers, no_data_found_response, 404
      mock.get "/api/v2/forms/9999#{api_url_suffix}?language=cy", req_headers, no_data_found_response, 404
      mock.get "/api/v2/forms/9999/archived", req_headers, no_data_found_response, 404
      mock.get "/api/v2/forms/9999/archived?language=cy", req_headers, no_data_found_response, 404
    end
  end

  describe "logging", :capture_logging do
    let(:form_id) { 2 }
    let(:trace_id) { "Root=1-63441c4a-abcdef012345678912345678" }
    let(:request_id) { "a-request-id" }

    before do
      get form_id_path(mode: "form", form_id:), headers: {
        "HTTP_X_AMZN_TRACE_ID": trace_id,
        "X-REQUEST-ID": request_id,
      }
    end

    it "logs when the form is visited" do
      expect(log_lines[0]["event"]).to eq("form_visit")
    end

    it "includes the form_name on log lines" do
      expect(log_lines[0]["form_name"]).to eq(form_response_data.name)
    end

    it "includes the form_id on log lines" do
      expect(log_lines[0]["form_id"]).to eq(form_id.to_s)
    end

    it "includes preview bool on log lines" do
      expect(log_lines[0]["preview"]).to eq("false")
    end

    it "includes the trace ID on log lines" do
      expect(log_lines[0]["trace_id"]).to eq(trace_id)
    end

    it "includes the request_host on log lines" do
      expect(log_lines[0]["request_host"]).to eq("www.example.com")
    end

    it "includes the request_id on log lines" do
      expect(log_lines[0]["request_id"]).to eq(request_id)
    end
  end

  describe "#redirect_to_user_friendly_url" do
    before do
      get form_id_path(mode: "form", form_id: 2)
    end

    context "when the form exists and has no start page" do
      let(:start_page) { nil }

      it "Returns a 404" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "#error_repeat_submission" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        allow(LogEventService).to receive(:log_form_start).at_least(:once)
        mock.get "/api/v2/forms/2/live", req_headers, form_response_data.to_json, 200
      end

      get error_repeat_submission_path(mode: "form", form_id: 2, form_slug: form_response_data.form_slug)
    end

    it "renders the page with a link back to the form start page" do
      expect(response.body).to include(form_step_path(mode: "form", form_id: 2, form_slug: form_response_data.form_slug, step_slug: 1))
    end
  end

  describe "#show" do
    context "with preview mode on" do
      context "with a draft form" do
        let(:api_url_suffix) { "/draft" }

        context "when a form exists" do
          before do
            allow(LogEventService).to receive(:log_form_start)
            travel_to timestamp_of_request do
              get form_path(mode: "preview-draft", form_id: 2, form_slug: form_response_data.form_slug)
            end
          end

          context "when the form has a start page" do
            it "Redirects to the first page" do
              expect(response).to redirect_to(form_step_path(mode: "preview-draft", form_id: 2, form_slug: form_response_data.form_slug, step_slug: 1))
            end

            it "does not log the form_visit event" do
              expect(LogEventService).not_to have_received(:log_form_start)
            end
          end

          context "when the form has no start page" do
            let(:start_page) { nil }

            it "returns 404" do
              expect(response).to have_http_status(:not_found)
            end
          end

          it "Returns the correct X-Robots-Tag header" do
            expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
          end

          describe "Privacy page" do
            it "returns http code 200" do
              get form_privacy_path(mode: "preview-draft", form_id: 2, form_slug: "form-name")
              expect(response).to have_http_status(:ok)
            end

            it "contains link to data controller's privacy policy" do
              get form_privacy_path(mode: "preview-draft", form_id: 2, form_slug: "form-name")
              expect(response.body).to include("http://www.example.gov.uk/privacy_policy")
            end
          end
        end

        context "when a form doesn't exists" do
          before do
            get form_path(mode: "preview-draft", form_id: 9999, form_slug: "form-name-1")
          end

          it "Render the not found page" do
            expect(response.body).to include(I18n.t("errors.not_found.title"))
          end

          it "returns 404" do
            expect(response).to have_http_status(:not_found)
          end
        end

        context "when the form has no start page" do
          let(:start_page) { nil }

          before do
            get form_path(mode: "preview-draft", form_id: 9999, form_slug: "form-name")
          end

          it "Render the not found page" do
            expect(response.body).to include(I18n.t("errors.not_found.title"))
          end

          it "returns 404" do
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context "with a live form" do
        let(:api_url_suffix) { "/live" }

        context "when a form exists" do
          before do
            allow(LogEventService).to receive(:log_form_start)
            travel_to timestamp_of_request do
              get form_path(mode: "preview-live", form_id: 2, form_slug: form_response_data.form_slug)
            end
          end

          context "when the form has a start page" do
            it "Redirects to the first page" do
              expect(response).to redirect_to(form_step_path(mode: "preview-live", form_id: 2, form_slug: form_response_data.form_slug, step_slug: 1))
            end

            it "does not log the form_visit event" do
              expect(LogEventService).not_to have_received(:log_form_start)
            end
          end

          context "when the form has no start page" do
            let(:start_page) { nil }

            it "returns 404" do
              expect(response).to have_http_status(:not_found)
            end
          end

          it "Returns the correct X-Robots-Tag header" do
            expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
          end

          describe "Privacy page" do
            it "returns http code 200" do
              get form_privacy_path(mode: "preview-live", form_id: 2, form_slug: form_response_data.form_slug)
              expect(response).to have_http_status(:ok)
            end

            it "contains link to data controller's privacy policy" do
              get form_privacy_path(mode: "preview-live", form_id: 2, form_slug: form_response_data.form_slug)
              expect(response.body).to include("http://www.example.gov.uk/privacy_policy")
            end
          end
        end

        context "when a form doesn't exists" do
          before do
            get form_path(mode: "preview-live", form_id: 9999, form_slug: "form-name-1")
          end

          it "Render the not found page" do
            expect(response.body).to include(I18n.t("errors.not_found.title"))
          end

          it "returns 404" do
            expect(response).to have_http_status(:not_found)
          end
        end

        context "when the form has no start page" do
          let(:start_page) { nil }

          before do
            get form_path(mode: "preview-live", form_id: 9999, form_slug: "form-name")
          end

          it "Render the not found page" do
            expect(response.body).to include(I18n.t("errors.not_found.title"))
          end

          it "returns 404" do
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    context "with preview mode off" do
      context "when a form is live" do
        context "when a form exists" do
          before do
            allow(LogEventService).to receive(:log_form_start)
            travel_to timestamp_of_request do
              get form_path(mode: "form", form_id: 2, form_slug: form_response_data.form_slug)
            end
          end

          context "when the form has a start page" do
            it "Redirects to the first page" do
              expect(response).to redirect_to(form_step_path(mode: "form", form_id: 2, form_slug: form_response_data.form_slug, step_slug: 1))
            end

            it "Logs the form_visit event" do
              expect(LogEventService).to have_received(:log_form_start)
            end
          end

          context "when the form has no start page" do
            let(:start_page) { nil }

            it "returns 404" do
              expect(response).to have_http_status(:not_found)
            end
          end

          it "Returns the correct X-Robots-Tag header" do
            expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
          end
        end

        context "when a live form doesn't exist" do
          before do
            get form_path(mode: "form", form_id: 9999, form_slug: "form-name")
          end

          it "returns 404" do
            expect(response).to have_http_status(:not_found)
          end

          it "Render the not found page" do
            expect(response.body).to include(I18n.t("errors.not_found.title"))
          end
        end
      end

      context "when the form is archived" do
        before do
          ActiveResource::HttpMock.respond_to do |mock|
            mock.get "/api/v2/forms/2/live", req_headers, nil, 404
            mock.get "/api/v2/forms/2/archived", req_headers, form_response_data.to_json, 200
          end

          get form_path(mode: "form", form_id: 2, form_slug: form_response_data.form_slug)
        end

        it "Renders the form archived page" do
          expect(response.body).to include(I18n.t("form.archived.title"))
        end
      end

      context "when the form is an archived Welsh form with a live English version" do
        before do
          ActiveResource::HttpMock.respond_to do |mock|
            mock.get "/api/v2/forms/2/live", req_headers, form_response_data.to_json, 200
            mock.get "/api/v2/forms/2/live?language=cy", req_headers, nil, 404
            mock.get "/api/v2/forms/2/archived?language=cy", req_headers, form_response_data.to_json, 200
          end

          get form_path(mode: "form", form_id: 2, form_slug: form_response_data.form_slug, locale: :cy)
        end

        it "Renders the form archived page" do
          expect(Capybara.string(response.body)).to have_text(I18n.t("forms.archived_welsh.show.heading", locale: :cy))
        end
      end
    end
  end

  describe "locale" do
    let(:locale) { nil }

    context "when getting a form page that exists" do
      before do
        get form_step_path(mode: "form", form_id: 2, form_slug: form_response_data.form_slug, step_slug: 1, locale:)
      end

      context "when the locale param is not set" do
        it "renders content in English" do
          expect(response.body).to include(I18n.t("support_details.get_help_with_this_form"))
        end

        it "renders links without the locale scope" do
          expect(response.body).to include(form_privacy_path(form_id: 2, form_slug: form_response_data.form_slug))
        end
      end

      context "when the locale param is set to English" do
        let(:locale) { "en" }

        it "renders content in English" do
          expect(response.body).to include(I18n.t("support_details.get_help_with_this_form"))
        end

        it "renders links with the default locale scope" do
          expect(response.body).to include(form_privacy_path(form_id: 2, form_slug: form_response_data.form_slug))
        end

        it "requests the form in English" do
          expect(ActiveResource::HttpMock.requests)
            .to include ActiveResource::Request.new(:get, "/api/v2/forms/2/live", nil, req_headers)
        end
      end

      context "when the locale param is set to Welsh" do
        let(:locale) { "cy" }

        it "renders content in Welsh" do
          expect(response.body).to include(I18n.t("support_details.get_help_with_this_form", locale: :cy))
        end

        it "renders links with the cy locale scope" do
          expect(response.body).to include(form_privacy_path(form_id: 2, form_slug: form_response_data.form_slug, locale: :cy))
        end

        it "requests the form in Welsh" do
          expect(ActiveResource::HttpMock.requests)
            .to include ActiveResource::Request.new(:get, "/api/v2/forms/2/live?language=cy", nil, req_headers)
        end
      end
    end
  end
end
