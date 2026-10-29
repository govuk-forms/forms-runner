require "rails_helper"

RSpec.describe Forms::ResumeOptionsController, type: :request do
  let(:form) do
    build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, save_and_return: "enabled")
  end

  let(:steps) do
    [
      build(:question_step, :with_text_settings, id: 1, next_step_id: 2),
      build(:question_step, :with_text_settings, id: 2),
    ]
  end

  let(:req_headers) { { "Accept" => "application/json" } }
  let(:api_url_suffix) { "/draft" }
  let(:mode) { "preview-draft" }

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}#{api_url_suffix}", req_headers, form.to_json, 200
    end
  end

  describe "GET #show" do
    before do
      get resume_options_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
    end

    it "renders the page asking whether to start a new form or continue a saved one" do
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end

    context "when save and return is disabled on the form" do
      let(:form) do
        build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, save_and_return: "disabled")
      end

      it "redirects to the first question" do
        expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 1, mode:))
      end
    end
  end

  describe "POST #continue" do
    before do
      post resume_options_continue_path(mode:, form_id: form.form_id, form_slug: form.form_slug),
           params: { resume_options_input: { resume_options: } }
    end

    context "when the user chooses to start a new form" do
      let(:resume_options) { "start_new" }

      it "redirects to the first question" do
        expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 1, mode:))
      end
    end

    context "when the user chooses to continue filling in a saved form" do
      let(:resume_options) { "continue_saved" }

      it "redirects to resume their saved progress" do
        expect(response).to redirect_to(resume_progress_path(form.form_id, form.form_slug, mode:))
      end
    end

    context "when the user does not choose an option" do
      let(:resume_options) { "" }

      it "shows the page again with an error" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:show)
        expect(response.body).to include(I18n.t("activemodel.errors.models.resume_options_input.attributes.resume_options.blank"))
      end
    end
  end
end
