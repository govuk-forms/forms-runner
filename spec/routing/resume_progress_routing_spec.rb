require "rails_helper"

RSpec.describe Forms::ResumeProgressController, type: :routing do
  describe "routing" do
    describe "#resume_progress" do
      it "routes to #new" do
        expect(get: resume_progress_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/resume_progress#new", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end

    describe "#resume_progress_signed_in" do
      it "routes to #signed_in" do
        expect(get: resume_progress_signed_in_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/resume_progress#signed_in", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end
  end
end
