require "rails_helper"

RSpec.describe Forms::BrandedAccessibilityStatementController, type: :request do
  let(:form_data) do
    build(:v2_form_document, :with_support,
          id: 2,
          start_page: 1,
          what_happens_next_markdown: "Good things come to those that wait",
          declaration_text: "agree to the declaration",
          steps: steps_data,
          brand_id: "cheshire-east")
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

  describe "#show" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/2/draft", req_headers, form_data.to_json, 200
      end

      get form_branded_accessibility_statement_path(mode: "preview-draft", form_id: 2, form_slug: form_data.form_slug)
    end

    it "renders the show branded accessibility statement page template" do
      expect(response).to render_template("forms/branded_accessibility_statement/show")
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "includes the custom branding favicon" do
      expect(response.body).to include("/brand_assets/cheshire-east/favicon.ico")
    end
  end
end
