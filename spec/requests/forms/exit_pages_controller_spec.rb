require "rails_helper"

RSpec.describe Forms::ExitPagesController, type: :request do
  let(:exit_page) { build(:v2_exit_page) }
  let(:steps) { [first_step_in_form, step_with_exit_page, next_step_in_form] }
  let(:first_step_in_form) { build(:v2_question_step, :with_text_settings, id: 1, next_step_id: 2) }
  let(:step_with_exit_page) { build(:v2_selection_question_step, :with_exit_page, id: 2, next_step_id: 3, exit_page:) }
  let(:next_step_in_form) { build(:v2_question_step, id: 3, next_step_id: nil) }
  let(:form) { build(:v2_form_document, steps:, start_page: 1) }

  let(:answer) { "Option 1" }

  let(:store) do
    {
      answers: {
        form.form_id.to_s => {
          first_step_in_form.id.to_s => { text: "first answer" },
          step_with_exit_page.id.to_s => { selection: answer },
        },
      },
    }
  end

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}/live", { "Accept" => "application/json" }, form.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, **kwargs|
      original_method.call(**kwargs, store:)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get exit_page_path(mode: "form", form_id: form.form_id, form_slug: form.form_slug, step_slug: step_with_exit_page.id)
      expect(response).to have_http_status(:success)
    end

    it "renders an exit page" do
      get exit_page_path(mode: "form", form_id: form.form_id, form_slug: form.form_slug, step_slug: step_with_exit_page.id)
      expect(response).to render_template(:show)
    end

    context "when the form filler has not answered any questions" do
      let(:store) { { answers: {} } }

      it "redirects to the start of the form" do
        get exit_page_path(mode: "form", form_id: form.form_id, form_slug: form.form_slug, step_slug: step_with_exit_page.id)
        expect(response).to redirect_to form_step_path(mode: "form", form_id: form.form_id, form_slug: form.form_slug, step_slug: first_step_in_form.id)
      end
    end
  end
end
