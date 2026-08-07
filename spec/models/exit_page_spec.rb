require "rails_helper"

RSpec.describe ExitPage do
  describe "#initialize" do
    it "sets the attributes" do
      exit_page = described_class.new(
        id: 1,
        heading: "You are not elegible for this service",
        markdown: "Here’s what to do next: ...",
      )

      expect(exit_page).to have_attributes(
        id: 1,
        heading: "You are not elegible for this service",
        markdown: "Here’s what to do next: ...",
      )
    end
  end

  describe ".from_form_document" do
    it "creates an exit page from a form document object" do
      form_document_exit_page = build(:v2_exit_page)
      exit_page = described_class.from_form_document(form_document_exit_page)

      expect(exit_page).to be_an described_class
      expect(exit_page).to have_attributes(
        id: form_document_exit_page.id,
        heading: form_document_exit_page.heading,
        markdown: form_document_exit_page.markdown,
      )
    end
  end

  describe "#==" do
    context "when other exit page was created from the same form document exit page" do
      it "returns true" do
        form_document_exit_page = build(:v2_exit_page)
        exit_page = described_class.from_form_document(form_document_exit_page)
        other_exit_page = described_class.from_form_document(form_document_exit_page)

        expect(exit_page == other_exit_page).to be true
      end
    end

    context "when other exit page was created from a different form document exit page" do
      it "returns false" do
        form_document_exit_page = build(:v2_exit_page)
        exit_page = described_class.from_form_document(form_document_exit_page)
        other_form_document_exit_page = build(:v2_exit_page)
        other_exit_page = described_class.from_form_document(other_form_document_exit_page)

        expect(exit_page == other_exit_page).to be false
      end
    end
  end
end
