require "rails_helper"

RSpec.describe Forms::PrivacyPageController, type: :request do
  let(:form_data) do
    build(:v2_form_document, :with_support,
          id: 2,
          start_page: 1,
          privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
          what_happens_next_markdown: "Good things come to those that wait",
          declaration_text: "agree to the declaration",
          steps: steps_data)
  end

  let(:steps_data) do
    [
      build(:v2_question_page_step,
            id: 1,
            position: 1,
            next_step_id: 2,
            type: "question",
            answer_type: "date",
            is_optional: nil,
            question_text: "Question one"),
      build(:v2_question_page_step,
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

      get form_privacy_path(mode: "preview-draft", form_id: 2, form_slug: form_data.form_slug)
    end

    it "includes the privacy policy URL" do
      expect(response.body).to include(form_data.privacy_policy_url)
    end

    it "renders the show privacy page template" do
      expect(response).to render_template("forms/privacy_page/show")
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end
  end
end
