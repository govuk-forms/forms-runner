require "rails_helper"

RSpec.describe Forms::ResumeOptionsController, type: :routing do
  describe "routing" do
    describe "#resume_options" do
      it "routes to #show" do
        expect(get: resume_options_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/resume_options#show", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end

    describe "#save_resume_options" do
      it "routes to #save" do
        expect(post: save_resume_options_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/resume_options#save", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end
  end
end
