require "rails_helper"

RSpec.describe ErrorsController, type: :request do
  describe "Page not found" do
    it "returns http code 404" do
      get error_404_path
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "root path" do
    it "returns http code 404" do
      get root_path
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "random non-exist path" do
    it "returns http code 404" do
      get "/random/string/"
      expect(response).to have_http_status(:not_found)
    end

    it "renders the not found template" do
      get "/random/string/"
      expect(response.body).to include(I18n.t("errors.not_found.title"))
    end
  end

  describe "Internal server error" do
    it "returns http code 500" do
      get error_500_path
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "Submission error" do
    let(:form_data) do
      build(
        :v2_form_document,
        :with_support,
        id: 2,
        name: "Form name",
        form_slug: "form-name",
        submission_email: "submission@email.com",
        start_page: 1,
        steps: [
          build(:v2_question_page_step, id: 1, answer_type: "text", answer_settings: { input_type: "single_line" }),
        ],
      )
    end

    let(:req_headers) { { "Accept" => "application/json" } }

    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/2/live", req_headers, form_data.to_json, 200
      end

      # setup the context in the session
      get form_step_path(mode: "form", form_id: 2, form_slug: "form-name", step_slug: 1)
      post save_form_step_path(mode: "form", form_id: 2, form_slug: "form-name", step_slug: 1, question: { text: "test" })

      allow(FormSubmissionService).to receive(:call).and_wrap_original do |original_method, **args|
        form_submission_service = original_method.call(**args)

        allow(form_submission_service).to receive(:deliver_submission)
          .and_raise("Oh no!").with(any_args)

        form_submission_service
      end
    end

    it "returns http code 500" do
      post form_submit_answers_path(
        mode: "form",
        form_id: 2,
        form_slug: "form-name",
        email_confirmation_input: {
          send_confirmation: "skip_confirmation",
          notify_reference: "test-ref",
        },
      )

      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "Maintenance" do
    before { get maintenance_page_path }

    it "returns http code 200" do
      expect(response).to have_http_status(:ok)
    end

    it "renders the maintenance page" do
      expect(response).to have_rendered("errors/maintenance")
    end
  end
end
