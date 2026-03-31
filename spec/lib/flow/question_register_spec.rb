require "rails_helper"
require "ostruct"

RSpec.describe Flow::QuestionRegister do
  it "returns a class given a valid answer_type" do
    %i[date address email national_insurance_number phone_number number organisation_name text].each do |type|
      form_document_step = OpenStruct.new(answer_type: type)
      expect { described_class.from_page(form_document_step) }.not_to raise_error
    end
  end

  it "raises ArgumentError when given an invalid argument type" do
    form_document_step = OpenStruct.new(answer_type: :invalid_type)
    expect { described_class.from_page(form_document_step) }.to raise_error(ArgumentError)
  end

  it "raises NoMethodError when when not given an object which reponds to answer_type" do
    form_document_step = nil
    expect { described_class.from_page(form_document_step) }.to raise_error(NoMethodError)
  end

  it "accepts is_optional for each answer_type" do
    [false, true].each do |is_optional|
      %i[date address email national_insurance_number phone_number number organisation_name text].each do |type|
        form_document_step = OpenStruct.new(answer_type: type, is_optional:)
        expect(described_class.from_page(form_document_step).is_optional?).to eq(is_optional)
      end
    end
  end

  context "when a question has guidance" do
    it "creates a question class with the page_heading and guidance_markdown" do
      %i[date address email national_insurance_number phone_number number organisation_name text].each do |type|
        form_document_step = OpenStruct.new(answer_type: type, page_heading: "New page heading", guidance_markdown: "## Heading level 2")
        result = described_class.from_page(form_document_step)
        expect(result.page_heading).to eq form_document_step.page_heading
        expect(result.guidance_markdown).to eq form_document_step.guidance_markdown
      end
    end
  end
end
