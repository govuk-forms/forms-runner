require "rails_helper"

RSpec.describe Forms::ReviewFileController, type: :request do
  let(:form_data) do
    build(:v2_form_document, :with_support, :live?,
          form_id: 1,
          start_page: 1,
          privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
          what_happens_next_markdown: "Good things come to those that wait",
          declaration_text: "agree to the declaration",
          steps: steps_data)
  end

  let(:file_upload_step) do
    build :v2_question_page_step,
          id: 1,
          next_step_id: 2,
          answer_type: "file"
  end

  let(:text_question_step) do
    build :v2_question_page_step, :with_text_settings,
          id: 2
  end

  let(:steps_data) { [file_upload_step, text_question_step] }

  let(:req_headers) { { "Accept" => "application/json" } }

  let(:api_url_suffix) { "/live" }
  let(:mode) { "form" }
  let(:changing_existing_answer) { false }

  let(:uploaded_filename) { "test.jpg" }
  let(:uploaded_file_key) { "test_key" }
  let(:store) do
    {
      answers: {
        form_data.form_id.to_s => {
          file_upload_step.id.to_s => {
            "original_filename" => uploaded_filename,
            "uploaded_file_key" => uploaded_file_key,
          },
        },
      },
    }
  end

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/1#{api_url_suffix}", req_headers, form_data.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      context_spy = original_method.call(form: args[0][:form], store:)
      context_spy
    end
  end

  describe "#show" do
    before do
      get review_file_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:, changing_existing_answer:)
    end

    context "when the question is a file upload question" do
      let(:step_slug) { file_upload_step.id }

      context "when a file has been uploaded" do
        it "renders the review file template" do
          expect(response).to render_template("forms/review_file/show")
        end

        it "displays the uploaded filename" do
          expect(response.body).to include(uploaded_filename)
        end

        it "displays a back link to the file upload page" do
          expect(response.body).to include(form_page_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug: file_upload_step.id))
        end
      end

      context "when a file has not been uploaded" do
        let(:store) { {} }

        it "redirects to the show page route" do
          expect(response).to redirect_to form_page_path(form_data.form_id, form_data.form_slug, step_slug)
        end
      end

      it "includes the changing_existing_answer query parameter for the continue URL" do
        rendered = Capybara.string(response.body)
        expected_url = review_file_continue_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:, changing_existing_answer:)
        expect(rendered).to have_css("form[action='#{expected_url}'][method='post']")
      end
    end

    context "when the question isn't a file upload question" do
      let(:step_slug) { text_question_step.id }

      it "redirects to the show page route" do
        expect(response).to redirect_to form_page_path(form_data.form_id, form_data.form_slug, step_slug)
      end
    end
  end

  describe "#continue" do
    before do
      post review_file_continue_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:, changing_existing_answer:)
    end

    context "when the question is a file upload question" do
      let(:step_slug) { file_upload_step.id.to_s }

      context "when a file has been uploaded" do
        it "redirects to the next step in the form" do
          expect(response).to redirect_to form_page_path(form_data.form_id, form_data.form_slug, text_question_step.id)
        end
      end

      context "when changing an existing answer" do
        let(:changing_existing_answer) { true }

        it "redirects to the check your answers page" do
          expect(response).to redirect_to(check_your_answers_path(form_data.form_id, form_data.form_slug, mode:))
        end
      end

      context "when a file has not been uploaded" do
        let(:uploaded_file_key) { nil }

        it "redirects to the show page route" do
          expect(response).to redirect_to form_page_path(form_data.form_id, form_data.form_slug, step_slug)
        end
      end
    end

    context "when the question isn't a file upload question" do
      let(:step_slug) { text_question_step.id }

      it "redirects to the show page route" do
        expect(response).to redirect_to form_page_path(form_data.form_id, form_data.form_slug, step_slug)
      end
    end
  end
end
