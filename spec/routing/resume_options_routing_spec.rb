require "rails_helper"

RSpec.describe Forms::ResumeOptionsController, type: :routing do
  describe "routing" do
    describe "#resume_options" do
      it "routes to #show" do
        expect(get: resume_options_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/resume_options#show", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end

    describe "#resume_options_continue" do
      it "routes to #continue" do
        expect(post: resume_options_continue_path(mode: "form", form_id: 999, form_slug: "valid-slug"))
          .to route_to("forms/resume_options#continue", mode: "form", form_id: "999", form_slug: "valid-slug")
      end
    end
  end
end
