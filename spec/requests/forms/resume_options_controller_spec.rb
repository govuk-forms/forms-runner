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
  end
end
