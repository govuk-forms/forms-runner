require "rails_helper"

RSpec.describe Forms::SubmittedController, type: :request do
  let(:form_data) do
    build(:v2_form_document, :with_support,
          form_id: 2,
          start_page: 1,
          privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
          what_happens_next_markdown: "Your application will be processed within a few days.\n\nContact us if you need to:\n\n-change the details of your application\n-cancel your application",
          declaration_text: "agree to the declaration",
          steps: steps_data)
  end

  let(:steps_data) do
    [
      build(:v2_question_page_step,
            id: 1,
            position: 1,
            question_text: "Question one",
            answer_type: "date",
            next_step_id: 2,
            is_optional: nil),
      build(:v2_question_page_step,
            id: 2,
            position: 2,
            question_text: "Question two",
            answer_type: "date",
            is_optional: nil),
    ]
  end

  let(:store) do
    {
      answers: {
        "2" => {
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

  let(:req_headers) { { "Accept" => "application/json" } }

  describe "#submitted" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/2/draft", req_headers, form_data.to_json, 200
      end

      post save_form_step_path(mode: "preview-draft", form_id: 2, form_slug: form_data.form_slug, step_slug: 1), params: { question: store[:answers]["2"]["1"] }
      post save_form_step_path(mode: "preview-draft", form_id: 2, form_slug: form_data.form_slug, step_slug: 2), params: { question: store[:answers]["2"]["2"] }

      # assert that we've set up the test correctly
      expect(controller.session[:answers].to_h).to match({ "2" => { "1" => a_hash_including(**store[:answers]["2"]["1"]), "2" => a_hash_including(**store[:answers]["2"]["2"]) } }) # rubocop: disable RSpec/ExpectInHook

      get form_submitted_path(mode: "preview-draft", form_id: 2, form_slug: form_data.form_slug)
    end

    it "renders the what happens next markdown" do
      expect(response.body).to include(HtmlMarkdownSanitizer.new.render_scrubbed_markdown(form_data.what_happens_next_markdown))
    end

    it "renders the submitted page template" do
      expect(response).to render_template("forms/submitted/submitted")
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "clears the context" do
      expect(controller.session[:answers]["2"]).to be_nil
    end
  end
end
