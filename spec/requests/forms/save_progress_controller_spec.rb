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
          "return_to" => "save_and_return",
        })
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

      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the page with the button to save progress" do
        expect(response).to render_template(:new)
        expect(response.body).to include("test@example.com")
      end
    end
  end

  describe "GET #after_sign_in" do
    def get_after_sign_in
      get save_progress_after_sign_in_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
    end

    context "when save and return is disabled on the form" do
      let(:form) do
        build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, available_languages:, save_and_return: "disabled")
      end

      let(:answers) do
        { "1" => { "text" => "answer 1" } }
      end

      before { get_after_sign_in }

      it "redirects to the next step in the form" do
        expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 2, mode:))
      end

      it "does not save the answers" do
        expect(IncompleteSubmission.count).to eq 0
      end
    end

    context "when the user is not signed in to GOV.UK One Login" do
      before { get_after_sign_in }

      it "redirects to the save progress sign-in interstitial" do
        expect(response).to redirect_to(save_progress_path(form.form_id, form.form_slug, mode:))
      end

      it "does not save the answers" do
        expect(IncompleteSubmission.count).to eq 0
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

      context "when the save progress flow has not been started" do
        before { get_after_sign_in }

        it "redirects to the save progress page" do
          expect(response).to redirect_to(save_progress_path(form.form_id, form.form_slug, mode:))
        end

        it "does not save the answers" do
          expect(IncompleteSubmission.count).to eq 0
        end
      end

      context "when the save progress flow has been started" do
        let(:auth_session) do
          super().merge(return_from_one_login: { return_to: "save_and_return" })
        end

        context "when the user does not have saved answers for the form" do
          before { get_after_sign_in }

          it "saves the current answers keyed by the One Login sub" do
            incomplete_submission = IncompleteSubmission.find_by(user_id: "user-sub-123", form_id: form.form_id)

            expect(incomplete_submission).to be_present
            expect(incomplete_submission.answers).to eq answers
            expect(incomplete_submission.mode).to eq mode
          end

          it "redirects to the progress saved confirmation page" do
            expect(response).to redirect_to(progress_saved_path(form.form_id, form.form_slug, mode:))
          end

          it "clears the return from One Login params so that the URL cannot be used to save again" do
            expect(store).not_to have_key "return_from_one_login"
          end
        end

        context "when the user already has saved answers for the form" do
          let(:previously_saved_answers) { { "1" => { "text" => "previous answer" } } }

          before do
            IncompleteSubmission.create!(user_id: "user-sub-123", form_id: form.form_id, answers: previously_saved_answers)

            get_after_sign_in
          end

          # TODO: this should redirect to a page asking the user to confirm the overwrite, once that page exists
          it "overwrites the saved answers" do
            incomplete_submission = IncompleteSubmission.find_by(user_id: "user-sub-123", form_id: form.form_id)

            expect(incomplete_submission.answers).to eq answers
          end

          it "redirects to the progress saved confirmation page" do
            expect(response).to redirect_to(progress_saved_path(form.form_id, form.form_slug, mode:))
          end
        end
      end
    end
  end

  describe "POST #create" do
    before do
      allow(SendProgressSavedEmailJob).to receive(:perform_later)
      post create_save_progress_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
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

      it "does not save the answers" do
        expect(IncompleteSubmission.count).to eq 0
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

      it "saves the current answers keyed by the One Login sub" do
        incomplete_submission = IncompleteSubmission.find_by(user_id: "user-sub-123", form_id: form.form_id)

        expect(incomplete_submission).to be_present
        expect(incomplete_submission.answers).to eq answers
        expect(incomplete_submission.mode).to eq mode
      end

      it "sends the progress saved email to the One Login email address" do
        expect(SendProgressSavedEmailJob).to have_received(:perform_later).with(
          incomplete_submission: IncompleteSubmission.find_by(user_id: "user-sub-123", form_id: form.form_id),
          email_address: "test@example.com",
        )
      end

      it "redirects to the progress saved confirmation page" do
        expect(response).to redirect_to(progress_saved_path(form.form_id, form.form_slug, mode:))
      end
    end

    context "when the user is not signed in to GOV.UK One Login" do
      it "redirects to the save progress sign-in interstitial" do
        expect(response).to redirect_to(save_progress_path(form.form_id, form.form_slug, mode:))
      end

      it "does not save the answers" do
        expect(IncompleteSubmission.count).to eq 0
      end

      it "does not send the progress saved email" do
        expect(SendProgressSavedEmailJob).not_to have_received(:perform_later)
      end
    end
  end

  describe "GET #show" do
    context "when save and return is disabled on the form" do
      let(:form) do
        build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, available_languages:, save_and_return: "disabled")
      end

      let(:answers) do
        { "1" => { "text" => "answer 1" } }
      end

      before do
        get progress_saved_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "redirects to the next step in the form" do
        expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 2, mode:))
      end
    end

    context "when save and return is enabled on the form" do
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
        IncompleteSubmission.create!(
          user_id: "user-sub-123",
          form_id: form.form_id,
          answers:,
          updated_at: Time.zone.local(2026, 10, 14, 12, 0, 0),
        )

        get progress_saved_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the confirmation page" do
        expect(response).to render_template(:show)
      end

      it "shows the email address of the submitter" do
        expect(response.body).to include("test@example.com")
      end

      it "shows the date the saved form will be deleted, 30 days after it was last saved" do
        expect(response.body).to include("We’ll delete your saved form on 13 November 2026.")
      end
    end

    context "when the user does not have saved answers for the form" do
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
        get progress_saved_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "redirects to the start of the save progress journey" do
        expect(response).to redirect_to(save_progress_path(form.form_id, form.form_slug, mode:))
      end
    end
  end
end
