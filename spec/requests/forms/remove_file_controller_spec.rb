require "rails_helper"

RSpec.describe Forms::RemoveFileController, type: :request do
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
    build :v2_question_step,
          id: 1,
          next_step_id: 2,
          answer_type: "file"
  end

  let(:text_question_step) do
    build :v2_question_step, :with_text_settings,
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
      get remove_file_confirmation_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:, changing_existing_answer:)
    end

    context "when the question is a file upload question" do
      let(:step_slug) { file_upload_step.id }

      context "when a file has been uploaded" do
        it "renders the remove file template" do
          expect(response).to render_template("forms/remove_file/show")
        end

        it "displays the uploaded filename" do
          expect(response.body).to include(uploaded_filename)
        end

        it "displays a back link to the review file page" do
          expect(response.body).to include(review_file_path(form_data.form_id, form_data.form_slug, step_slug, changing_existing_answer:))
        end
      end

      context "when a file has not been uploaded" do
        let(:store) { {} }

        it "redirects to the show page route" do
          expect(response).to redirect_to form_step_path(form_data.form_id, form_data.form_slug, step_slug)
        end
      end

      context "when changing an existing answer" do
        let(:changing_existing_answer) { true }

        it "includes the changing_existing_answer query parameter for the confirmation URL" do
          rendered = Capybara.string(response.body)
          expected_url = remove_file_confirmation_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:, changing_existing_answer:)
          expect(rendered).to have_css("form[action='#{expected_url}'][method='post']")
        end
      end
    end

    context "when the question isn't a file upload question" do
      let(:step_slug) { text_question_step.id }

      it "redirects to the show page route" do
        expect(response).to redirect_to form_step_path(form_data.form_id, form_data.form_slug, step_slug)
      end
    end
  end

  describe "#delete" do
    let(:mock_s3_client) { Aws::S3::Client.new(stub_responses: true) }
    let(:remove) { "yes" }

    before do
      allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
      allow(mock_s3_client).to receive(:delete_object)
      delete remove_file_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:, changing_existing_answer:, remove_input: { remove: })
    end

    context "when the question is a file upload question" do
      let(:step_slug) { file_upload_step.id.to_s }

      context "when the input object validation fails" do
        let(:remove) { "invalid" }

        it "renders the remove file page with 422 status" do
          expect(response).to render_template("forms/remove_file/show")
          expect(response).to have_http_status :unprocessable_content
        end

        it "displays an error" do
          rendered = Capybara.string(response.body)
          expect(rendered).to have_css(".govuk-error-summary")
        end

        it "displays a back link to the review file page" do
          expect(response.body).to include(review_file_path(form_data.form_id, form_data.form_slug, step_slug, changing_existing_answer:))
        end
      end

      context "when the user has confirmed they want to remove their file" do
        context "when a file has been uploaded" do
          it "deletes the file from S3" do
            expect(mock_s3_client).to have_received(:delete_object)
          end

          it "removes the answer from the session" do
            expect(store[:answers][form_data.form_id.to_s]).not_to have_key step_slug
          end

          it "redirects to the show page route" do
            expect(response).to redirect_to form_step_path(form_data.form_id, form_data.form_slug, step_slug)
          end

          it "displays a success banner" do
            expect(flash[:success]).to eq(I18n.t("banner.success.file_removed"))
          end

          context "when changing an existing answer" do
            let(:changing_existing_answer) { true }

            it "redirects to the change answer route" do
              expect(response).to redirect_to form_change_answer_path(form_data.form_id, form_data.form_slug, step_slug)
            end
          end
        end

        context "when a file has not been uploaded" do
          let(:uploaded_file_key) { nil }

          it "does not remove the answer from the session" do
            expect(store[:answers][form_data.form_id.to_s]).to have_key step_slug
          end

          it "redirects to the show page route" do
            expect(response).to redirect_to form_step_path(form_data.form_id, form_data.form_slug, step_slug)
          end
        end
      end

      context "when the user has not confirmed they want to remove their file" do
        let(:remove) { "no" }

        it "does not delete the file from S3" do
          expect(mock_s3_client).not_to have_received(:delete_object)
        end

        it "does not remove the answer from the session" do
          expect(store[:answers][form_data.form_id.to_s]).to have_key step_slug
        end

        it "redirects to the review file page route" do
          expect(response).to redirect_to review_file_path(form_data.form_id, form_data.form_slug, step_slug, changing_existing_answer:)
        end
      end
    end

    context "when the question isn't a file upload question" do
      let(:step_slug) { text_question_step.id.to_s }
      let(:store) do
        {
          answers: {
            form_data.form_id.to_s => {
              text_question_step.id.to_s => {
                "text" => "foo",
              },
            },
          },
        }
      end

      it "does not remove the answer from the session" do
        expect(store[:answers][form_data.form_id.to_s]).to have_key step_slug
      end

      it "redirects to the show page route" do
        expect(response).to redirect_to form_step_path(form_data.form_id, form_data.form_slug, step_slug)
      end
    end
  end
end
