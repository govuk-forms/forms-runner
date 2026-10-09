require "rails_helper"

RSpec.describe Forms::SaveProgressController, type: :request do
  let(:form) do
    build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, available_languages:, save_and_return: "enabled")
  end

  let(:steps) do
    [
      build(:question_step, :with_text_settings, id: 1, next_step_id: 2),
      build(:question_step, :with_text_settings, id: 2),
    ]
  end

  let(:available_languages) { %w[en] }

  let(:req_headers) { { "Accept" => "application/json" } }
  let(:api_url_suffix) { "/draft" }
  let(:mode) { "preview-draft" }

  let(:answers) do
    {
      "1" => { "text" => "answer 1" },
      "2" => { "text" => "answer 2" },
    }
  end

  let(:auth_session) { {} }

  let(:store) do
    {
      answers: { form.form_id.to_s => answers },
    }.merge(auth_session).with_indifferent_access
  end

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}#{api_url_suffix}", req_headers, form.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      original_method.call(form: args[0][:form], form_document: args[0][:form_document], store:)
    end
    allow(AuthService).to receive(:new).and_wrap_original do |original_method, *_args|
      original_method.call(store)
    end
  end

  describe "GET #new" do
    context "when save and return is disabled on the form" do
      let(:form) do
        build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, available_languages:, save_and_return: "disabled")
      end

      let(:answers) do
        { "1" => { "text" => "answer 1" } }
      end

      before do
        get save_progress_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "redirects to the next step in the form" do
        expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 2, mode:))
      end
    end

    context "when the user is not signed in to GOV.UK One Login" do
      before do
        get save_progress_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the One Login sign-in interstitial" do
        expect(response).to render_template(:new)
      end

      it "stores the save progress return params for returning from One Login on the session" do
        expect(store).to have_key "return_from_one_login"
        expect(store["return_from_one_login"]).to eq({
          "last_form_id" => form.form_id,
          "last_form_slug" => form.form_slug,
          "last_mode" => mode.to_s,
          "last_locale" => nil,
          "return_to" => "save_progress",
        })
      end

      it "does not save the answers" do
        expect(SavedAnswer.count).to eq 0
      end
    end

    context "when the user is signed in to GOV.UK One Login" do
      let(:auth_session) do
        {
          auth: {
            sub: "user-sub-123",
            email: "test@example.com",
            token: "a-token",
            authenticated_at: Time.current.to_i,
          },
        }
      end

      before do
        get save_progress_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "redirects to the progress saved confirmation page" do
        expect(response).to redirect_to(progress_saved_path(form.form_id, form.form_slug, mode:))
      end

      it "saves the current answers keyed by the One Login sub" do
        saved_answer = SavedAnswer.find_by(user_id: "user-sub-123", form_id: form.form_id)

        expect(saved_answer).to be_present
        expect(saved_answer.answers).to eq answers
      end
    end
  end

  describe "GET #show" do
    before do
      get progress_saved_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
    end

    context "when save and return is disabled on the form" do
      let(:form) do
        build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, available_languages:, save_and_return: "disabled")
      end

      let(:answers) do
        { "1" => { "text" => "answer 1" } }
      end

      it "redirects to the next step in the form" do
        expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 2, mode:))
      end
    end

    context "when save and return is enabled on the form" do
      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the confirmation page" do
        expect(response).to render_template(:show)
      end
    end
  end
end
