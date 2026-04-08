require "rails_helper"

RSpec.describe Form, type: :model do
  subject(:form) { described_class.new(attributes) }

  let(:attributes) { { id: 1, name: "form name", submission_email: "user@example.com", start_page: 1, steps: } }

  let(:form_document_steps) do
    [
      { id: 9, next_page: 10, answer_type: "date", question_text: "Question one" },
      { id: 10, answer_type: "address", question_text: "Question two" },
    ]
  end

  describe "#form_id" do
    context "when the form is initialised with attribute form_id" do
      let(:attributes) { { form_id: "1" } }

      it "returns the form ID" do
        expect(form).to have_attributes form_id: "1"
      end

      it "equals #id" do
        expect(form.form_id).to eq form.id
      end
    end

    context "when the form is initialised with attribute id" do
      let(:attributes) { { id: 1 } }

      it "returns the form ID" do
        expect(form).to have_attributes form_id: 1
      end

      it "equals #id" do
        expect(form.form_id).to eq form.id
      end
    end
  end

  describe "#form_document_steps" do
    let(:form_document) { build :v2_form_document, steps: }
    let(:steps) do
      [
        build(:v2_question_step, id: 9, next_step_id: 10, answer_type: "date", question_text: "Question one"),
        build(:v2_question_step, id: 10, answer_type: "address", question_text: "Question two"),
      ]
    end

    it "returns the form_document_steps for the form" do
      form_document_steps = form.form_document_steps
      expect(form_document_steps.length).to eq(2)
      expect(form_document_steps[0].id).to eq(9)
      expect(form_document_steps[0].next_step_id).to eq(10)
      expect(form_document_steps[0].answer_type).to eq("date")
      expect(form_document_steps[0].question_text).to eq("Question one")
      expect(form_document_steps[1].id).to eq(10)
      expect(form_document_steps[1].answer_type).to eq("address")
      expect(form_document_steps[1].question_text).to eq("Question two")
    end
  end

  describe "#payment_url_with_reference" do
    let(:attributes) { { id: 1, name: "form name", payment_url:, start_page: 1 } }
    let(:reference) { SecureRandom.base58(8).upcase }

    context "when there is a payment_url" do
      let(:payment_url) { "https://www.gov.uk/payments/test-service/pay-for-licence" }

      it "returns a full payment link" do
        expect(form.payment_url_with_reference(reference)).to eq("#{payment_url}?reference=#{reference}")
      end
    end

    context "when there is no payment_url" do
      let(:payment_url) { nil }

      it "returns nil" do
        expect(form.payment_url_with_reference(reference)).to be_nil
      end
    end
  end

  describe "#submission_format" do
    context "when the submission format attribute is nil" do
      let(:attributes) { { submission_format: nil } }

      it "returns no submission delivery formats" do
        expect(form.submission_format).to eq []
      end
    end

    context "when the submission format attribute is an array of strings" do
      let(:attributes) { { submission_format: %w[csv json] } }

      it "returns the submission format attribute" do
        expect(form.submission_format).to eq %w[csv json]
      end
    end
  end

  describe "#support_details" do
    let(:attributes) do
      {
        id: 1,
        name: "form name",
        support_email: "help@example.gov.uk",
        support_phone: "0203 222 2222",
        support_url: "https://example.gov.uk/help",
        support_url_text: "Get help with this form",
        start_page: 1,
      }
    end

    it "returns an OpenStruct with support details" do
      support_details = form.support_details

      expect(support_details.email).to eq("help@example.gov.uk")
      expect(support_details.phone).to eq("0203 222 2222")
      expect(support_details.url).to eq("https://example.gov.uk/help")
      expect(support_details.url_text).to eq("Get help with this form")
      expect(support_details.call_charges_url).to eq("https://www.gov.uk/call-charges")
    end
  end

  describe "#language" do
    context "when the form is initialised with \"cy\" attribute language" do
      let(:attributes) { { id: 1, name: "form name", language: "cy" } }

      it "returns the language of the form" do
        expect(form.language).to eq(:cy)
      end

      it "#english? returns false" do
        expect(form.english?).to be false
      end

      it "#welsh? returns true" do
        expect(form.welsh?).to be true
      end
    end

    context "when the form is initialised without attribute language" do
      let(:attributes) { { id: 1, name: "form name" } }

      it "returns the default language of the form" do
        expect(form.language).to eq(:en)
      end

      it "#english? returns true" do
        expect(form.english?).to be true
      end

      it "#welsh? returns false" do
        expect(form.welsh?).to be false
      end
    end

    context "when the form is initialised with attribute language as nil" do
      let(:attributes) { { id: 1, name: "form name", language: nil } }

      it "returns the default language of the form" do
        expect(form.language).to eq(:en)
      end

      it "#english? returns true" do
        expect(form.english?).to be true
      end

      it "#welsh? returns false" do
        expect(form.welsh?).to be false
      end
    end
  end

  describe "#multilingual?" do
    context "when the form does not have an available_languages field" do
      let(:attributes) { { id: 1, name: "form name", submission_email: "user@example.com", start_page: 1 } }

      it "returns false" do
        expect(form.multilingual?).to be false
      end
    end

    context "when the form has an available_languages field" do
      context "when the form has only one available language" do
        let(:attributes) { { id: 1, name: "form name", submission_email: "user@example.com", start_page: 1, available_languages: %w[en] } }

        it "returns false" do
          expect(form.multilingual?).to be false
        end
      end

      context "when the form has more than one available language" do
        let(:attributes) { { id: 1, name: "form name", submission_email: "user@example.com", start_page: 1, available_languages: %w[en cy] } }

        it "returns true" do
          expect(form.multilingual?).to be true
        end
      end
    end
  end
end
