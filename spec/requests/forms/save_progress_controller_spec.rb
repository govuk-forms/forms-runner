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

  let(:submission_uuid) { SecureRandom.uuid }

  let(:store) do
    {
      answers: { form.form_id.to_s => answers },
      confirmation_details: { form.form_id.to_s => { "submission_uuid" => submission_uuid } },
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

  def back_link_href
    Capybara.string(response.body).find("a.govuk-back-link")[:href]
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

      it "has a back link to the next page in the form" do
        expect(back_link_href).to eq check_your_answers_path(form_id: form.form_id, form_slug: form.form_slug, mode:)
      end

      context "when the next question has not been answered yet" do
        let(:answers) { { "1" => { "text" => "answer 1" } } }

        it "has a back link to the unanswered question" do
          expect(back_link_href).to eq form_step_path(form.form_id, form.form_slug, 2, mode:)
        end
      end

      context "when no questions have been answered" do
        let(:answers) { {} }

        it "has a back link to the first question" do
          expect(back_link_href).to eq form_step_path(form.form_id, form.form_slug, 1, mode:)
        end
      end

      context "when the last answered question is repeatable" do
        let(:steps) do
          [
            build(:question_step, :with_text_settings, :with_repeatable, id: 1, next_step_id: 2),
            build(:question_step, :with_text_settings, id: 2),
          ]
        end
        let(:answers) { { "1" => [{ "text" => "answer 1" }] } }

        it "has a back link to the add another answer page" do
          expect(back_link_href).to eq add_another_answer_path(form_id: form.form_id, form_slug: form.form_slug, step_slug: 1, mode:)
        end
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

      it "has a back link to the next page in the form" do
        expect(back_link_href).to eq check_your_answers_path(form_id: form.form_id, form_slug: form.form_slug, mode:)
      end

      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the page asking whether to continue with the signed in GOV.UK One Login" do
        expect(response).to render_template(:signed_in)
        expect(response.body).to include("test@example.com")
        expect(response.body).to include("Do you want to continue with this GOV.UK One Login?")
      end

      context "when the user already has saved answers for the form" do
        before do
          create(:incomplete_submission,
                 user_id: "user-sub-123",
                 form_id: form.form_id,
                 answers: { "1" => { "text" => "previous answer" } },
                 mode:)

          get save_progress_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
        end

        it "renders the page asking whether to continue with the signed in GOV.UK One Login" do
          expect(response).to render_template(:signed_in)
        end
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
          super().merge(return_from_one_login: { return_to: "save_progress" })
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
            create(:incomplete_submission, user_id: "user-sub-123", form_id: form.form_id, answers: previously_saved_answers, mode:)

            get_after_sign_in
          end

          it "renders the page asking whether to replace the saved answers" do
            expect(response).to render_template(:already_saved)
          end

          it "clears the return from One Login params" do
            expect(store).not_to have_key "return_from_one_login"
          end
        end
      end
    end
  end

  describe "POST #overwrite" do
    let(:already_saved_choice) { "overwrite" }

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
      allow(SendProgressSavedEmailJob).to receive(:perform_later)
      create(:incomplete_submission, user_id: "user-sub-123", form_id: form.form_id, answers: { "1" => { "text" => "previous answer" } }, mode:)
      post overwrite_saved_progress_path(mode:, form_id: form.form_id, form_slug: form.form_slug),
           params: { already_saved_input: { already_saved: already_saved_choice } }
    end

    context "when the user chooses to overwrite the saved version" do
      it "overwrites the saved answers after the user confirms" do
        incomplete_submission = IncompleteSubmission.find_by(user_id: "user-sub-123", form_id: form.form_id)

        expect(incomplete_submission.answers).to eq answers
      end

      it "redirects to the progress saved confirmation page" do
        expect(response).to redirect_to(progress_saved_path(form.form_id, form.form_slug, mode:))
      end
    end

    context "when the user chooses to keep the saved version" do
      let(:already_saved_choice) { "keep_saved" }

      it "does not overwrite the saved answers" do
        incomplete_submission = IncompleteSubmission.find_by(user_id: "user-sub-123", form_id: form.form_id)

        expect(incomplete_submission.answers).to eq("1" => { "text" => "previous answer" })
      end

      it "returns the user to the page after the last answered question" do
        expect(response).to redirect_to(check_your_answers_path(form_id: form.form_id, form_slug: form.form_slug, mode:))
      end

      context "when no questions have been answered" do
        let(:answers) { {} }

        it "returns the user to the first question" do
          expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 1, mode:))
        end
      end

      context "when the last answered question is repeatable" do
        let(:steps) do
          [
            build(:question_step, :with_text_settings, :with_repeatable, id: 1, next_step_id: 2),
            build(:question_step, :with_text_settings, id: 2),
          ]
        end
        let(:answers) { { "1" => [{ "text" => "answer 1" }] } }

        it "returns the user to the add another answer page" do
          expect(response).to redirect_to(add_another_answer_path(form_id: form.form_id, form_slug: form.form_slug, step_slug: 1, mode:))
        end
      end

      context "when the last answered question routes to an exit page" do
        let(:exit_page) { build(:exit_page) }
        let(:steps) do
          [
            build(:selection_question_step, :with_exit_page, id: 1, next_step_id: 2, exit_page:),
            build(:question_step, :with_text_settings, id: 2),
          ]
        end
        let(:answers) { { "1" => { "selection" => "Option 1" } } }

        it "returns the user to the exit page" do
          expect(response).to redirect_to(exit_page_path(form_id: form.form_id, form_slug: form.form_slug, step_slug: 1, exit_page_id: exit_page.id, mode:))
        end
      end
    end

    context "when the user does not choose an option" do
      let(:already_saved_choice) { nil }

      it "renders the page with a validation error" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:already_saved)
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
        create(:incomplete_submission,
               user_id: "user-sub-123",
               form_id: form.form_id,
               answers:,
               mode:,
               updated_at: Time.zone.local(2026, 10, 14, 12, 0, 0))

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

      it "has a button to continue to the page after the last answered question" do
        expect(response.body).to include(%(href="#{check_your_answers_path(form_id: form.form_id, form_slug: form.form_slug, mode:)}"))
      end

      context "when no questions have been answered" do
        let(:answers) { {} }

        it "has a button to continue to the first question" do
          expect(response.body).to include(%(href="#{form_step_path(form.form_id, form.form_slug, 1, mode:)}"))
        end
      end

      context "when the last answered question routes to an exit page" do
        let(:exit_page) { build(:exit_page) }
        let(:steps) do
          [
            build(:selection_question_step, :with_exit_page, id: 1, next_step_id: 2, exit_page:),
            build(:question_step, :with_text_settings, id: 2),
          ]
        end
        let(:answers) { { "1" => { "selection" => "Option 1" } } }

        it "has a button to continue to the exit page" do
          expect(response.body).to include(%(href="#{exit_page_path(form_id: form.form_id, form_slug: form.form_slug, step_slug: 1, exit_page_id: exit_page.id, mode:)}"))
        end
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
