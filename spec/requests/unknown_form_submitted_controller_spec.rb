require "rails_helper"

RSpec.describe UnknownFormSubmittedController, type: :request do
  describe "GET #show" do
    it "renders the show template" do
      get unknown_form_submitted_path

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end
  end
end
