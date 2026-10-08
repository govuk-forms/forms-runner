require "rails_helper"

RSpec.describe Forms::SaveProgressController, type: :routing do
  describe "routing" do
    describe "#save_progress" do
      it "routes to #new" do
        expect(get: save_progress_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/save_progress#new", mode: "form", form_id: "999", form_slug: "valid-slug")
      end

      it "does not route for an invalid form_id" do
        expect { save_progress_path(mode: "form", form_id: "invalid", form_slug: "valid-slug") }.to raise_error(ActionController::UrlGenerationError)
      end

      it "does not route for an invalid mode" do
        expect { save_progress_path(mode: "invalid", form_id: 999, form_slug: "valid-slug") }.to raise_error(ActionController::UrlGenerationError)
      end

      it "does not route for an invalid form_slug" do
        expect { save_progress_path(mode: "form", form_id: 999, form_slug: "invalid~slug") }.to raise_error(ActionController::UrlGenerationError)
      end
    end

    describe "#form_progress_saved" do
      it "routes to #show" do
        expect(get: progress_saved_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/save_progress#show", mode: "form", form_id: "999", form_slug: "valid-slug")
      end

      it "does not route for an invalid form_id" do
        expect { progress_saved_path(mode: "form", form_id: "invalid", form_slug: "valid-slug") }.to raise_error(ActionController::UrlGenerationError)
      end

      it "does not route for an invalid mode" do
        expect { progress_saved_path(mode: "invalid", form_id: 999, form_slug: "valid-slug") }.to raise_error(ActionController::UrlGenerationError)
      end

      it "does not route for an invalid form_slug" do
        expect { progress_saved_path(mode: "form", form_id: 999, form_slug: "invalid~slug") }.to raise_error(ActionController::UrlGenerationError)
      end
    end
  end
end
