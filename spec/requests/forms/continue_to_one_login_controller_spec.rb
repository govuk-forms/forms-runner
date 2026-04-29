require "rails_helper"

RSpec.describe Forms::ContinueToOneLoginController do
  let(:form) { build :v2_form_document, steps:, start_page: 1, available_languages: }

  let(:steps) do
    [
      build(:v2_question_step, :with_text_settings, id: 1, next_step_id: 2),
      build(:v2_question_step, :with_text_settings, id: 2),
    ]
  end

  let(:available_languages) { %w[en cy] }
  let(:mode) { "preview-draft" }
  let(:locale) { :en }

  let(:req_headers) { { "Accept" => "application/json" } }
  let(:api_url_suffix) { "/draft" }

  let(:store) do
    {
      answers: {
        form.form_id.to_s => {
          "1" => { "text" => "answer 1" },
          "2" => { "text" => "answer 2" },
        },
      },
    }
  end

  before do
    language_suffix = "?language=#{locale}" if locale == :cy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}#{api_url_suffix}#{language_suffix}", req_headers, form.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      original_method.call(form: args[0][:form], form_document: args[0][:form_document], store:)
    end
    allow(AuthService).to receive(:new).and_wrap_original do |original_method, *_args|
      original_method.call(store)
    end
  end

  describe "GET #show" do
    before do
      get continue_to_one_login_path(mode:, form_id: form.form_id, form_slug: form.form_slug, locale:)
    end

    context "when the feature flag is disabled", feature_filler_answer_email_enabled: false do
      it "redirects to check your answers" do
        expect(response).to redirect_to(check_your_answers_path(form_id: form.form_id, form_slug: form.form_slug, mode:))
      end
    end

    context "when the feature flag is enabled", :feature_filler_answer_email_enabled do
      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the show template" do
        expect(response).to render_template(:show)
      end

      it "saves the path params for returning from One Login on the session" do
        expect(store).to have_key "return_from_one_login"
        expect(store["return_from_one_login"]).to eq({
          "last_form_id" => form.form_id,
          "last_form_slug" => form.form_slug,
          "last_mode" => mode.to_s,
          "last_locale" => nil,
        })
      end

      context "when the locale is Welsh" do
        let(:locale) { :cy }

        it "saves the locale on the session" do
          expect(store["return_from_one_login"]["last_locale"]).to eq("cy")
        end
      end

      context "when the form is not multilingual" do
        let(:available_languages) { %w[en] }

        it "does not include the language switcher" do
          expect(response.body).not_to include(I18n.t("language_switcher.nav_label"))
        end
      end

      context "when the form is multilingual" do
        let(:available_languages) { %w[en cy] }

        it "includes the language switcher" do
          expect(response.body).to include(I18n.t("language_switcher.nav_label"))
        end
      end

      context "when all questions have not been completed" do
        let(:store) do
          {
            answers: {
              form.form_id.to_s => {
                "1" => { "text" => "answer 1" },
              },
            },
          }
        end

        it "redirects to the next page" do
          expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 2, mode:))
        end
      end
    end
  end
end
