require "rails_helper"

RSpec.describe Forms::ContinueSavedFormController, type: :routing do
  describe "routing" do
    describe "#continue_saved_form" do
      it "routes to #new" do
        expect(get: continue_saved_form_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/continue_saved_form#new", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end

    describe "#continue_saved_form_signed_in" do
      it "routes to #signed_in" do
        expect(get: continue_saved_form_signed_in_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/continue_saved_form#signed_in", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end
  end
end
