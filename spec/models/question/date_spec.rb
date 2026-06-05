require "rails_helper"

RSpec.describe Question::Date, type: :model do
  subject(:question) { described_class.new({}, options) }

  let(:options) { { is_optional:, question_text: } }

  let(:is_optional) { false }
  let(:question_text) { Faker::Lorem.question }

  it_behaves_like "a question model"

  context "when a date has an empty day, month and year" do
    it "returns invalid with blank date" do
      expect(question).not_to be_valid
      expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.blank"))
    end

    it "returns invalid with empty string" do
      set_date("", "", "")
      expect(question).not_to be_valid
      expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.blank"))
    end

    it "shows as a blank string" do
      expect(question.show_answer).to eq ""
    end

    it "returns a hash with an blank value for show_answer_in_csv" do
      expect(question.show_answer_in_csv).to eq(Hash[question_text, ""])
    end
  end

  context "when a date has empty day, month or year" do
    it "returns invalid with a message" do
      day_month_years = [
        [1, nil, 2022],
        [nil, 1, 2022],
        [1, 1, nil],
      ]

      day_month_years.each do |v|
        set_date(*v)
        expect(question).not_to be_valid
        expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.blank_date_fields"))
      end
    end
  end

  context "when a date has a valid day, month or year" do
    before do
      set_date("31", "12", "2021")
    end

    it "displays date in the correct format" do
      expect(question.show_answer).to eq "31/12/2021"
    end

    it "is valid" do
      expect(question).to be_valid
    end

    it "returns the whole date as one item in show_answer_in_csv" do
      expect(question.show_answer_in_csv).to eq(Hash[question_text, "31/12/2021"])
    end
  end

  context "when a date has a day, month or year but it's not a real date" do
    before do
      set_date("45", "02", "2021")
    end

    it "isn't valid" do
      expect(question).not_to be_valid
      expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.invalid_date"))
    end

    it "returns a hash with an blank value for show_answer_in_csv" do
      expect(question.show_answer_in_csv).to eq(Hash[question_text, ""])
    end
  end

  context "when a year is not 4-digits" do
    let(:year) { "2023" }

    before do
      set_date("01", "11", year)
    end

    context "when year is less than 1000" do
      let(:year) { "567" }

      it "isn't valid" do
        expect(question).not_to be_valid
        expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.invalid_number_of_digits_for_year"))
      end
    end

    context "when year is 1000" do
      let(:year) { "1000" }

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "when year is between 1000 and 9999" do
      let(:year) { "3400" }

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "when year is 9999" do
      let(:year) { "9999" }

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "when year more than 9999" do
      let(:year) { "10000" }

      it "isn't valid" do
        expect(question).not_to be_valid
        expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.invalid_number_of_digits_for_year"))
      end
    end
  end

  context "when given non-integers as values for day, month or year" do
    it "isn't valid" do
      day_month_years = [
        [1, "e", 2022],
        ["pi", 1, 2022],
        [1, 1, "zero"],
      ]

      day_month_years.each do |v|
        set_date(*v)
        expect(question).not_to be_valid
        expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.invalid_date"))
      end
    end

    context "when question is date of birth" do
      let(:options) { OpenStruct.new(answer_settings: OpenStruct.new(input_type: "date_of_birth")) }

      it "isn't valid" do
        day_month_years = [
          [1, "e", 2022],
          ["pi", 1, 2022],
          [1, 1, "zero"],
        ]
        question.answer_settings = { input_type: "date_of_birth" }

        day_month_years.each do |v|
          set_date(*v)
          expect(question).not_to be_valid
          expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.invalid_date"))
        end
      end
    end
  end

  context "when question is optional" do
    let(:is_optional) { true }

    it "returns valid with blank date" do
      expect(question).to be_valid
      expect(question.errors[:date]).not_to include(I18n.t("activemodel.errors.models.question/date.attributes.date.blank"))
    end

    it "returns valid with empty string" do
      set_date("", "", "")
      expect(question).to be_valid
      expect(question.errors[:date]).not_to include(I18n.t("activemodel.errors.models.question/date.attributes.date.blank"))
    end

    context "when a date has empty day, month or year" do
      it "returns invalid with a message" do
        day_month_years = [
          [1, nil, 2022],
          [nil, 1, 2022],
          [1, 1, nil],
        ]

        day_month_years.each do |v|
          set_date(*v)
          expect(question).not_to be_valid
          expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.blank_date_fields"))
        end
      end
    end

    context "when a date has a valid day, month or year" do
      before do
        set_date("31", "12", "2021")
      end

      it "displays date in the correct format" do
        expect(question.show_answer).to eq "31/12/2021"
      end

      it "is valid" do
        expect(question).to be_valid
      end

      it "returns the whole date as one item in show_answer_in_csv" do
        expect(question.show_answer_in_csv).to eq(Hash[question_text, "31/12/2021"])
      end
    end

    context "when a date has a valid day, month or year but it's not a real date" do
      before do
        set_date("45", "02", "2021")
      end

      it "isn't valid" do
        expect(question).not_to be_valid
        expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.invalid_date"))
      end
    end

    context "when given non-integers as values for day, month or year" do
      it "isn't valid" do
        day_month_years = [
          [1, "e", 2022],
          ["pi", 1, 2022],
          [1, 1, "zero"],
        ]

        day_month_years.each do |v|
          set_date(*v)
          expect(question).not_to be_valid
          expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.invalid_date"))
        end
      end
    end

    context "when the input type is a date of birth" do
      let(:options) { { answer_settings: OpenStruct.new({ input_type: "date_of_birth" }) } }

      before do
        set_date(*date_input)
      end

      context "when the date is in the past" do
        let(:date_input) { ["01", "01", (Time.zone.today.year - 1).to_s] }

        it "is valid" do
          expect(question).to be_valid
          expect(question.errors[:date]).to eq []
        end
      end

      context "when the date is in the future" do
        let(:date_input) { ["01", "01", (Time.zone.today.year + 1).to_s] }

        it "isn't valid" do
          expect(question).not_to be_valid
          expect(question.errors[:date]).to include(I18n.t("activemodel.errors.models.question/date.attributes.date.future_date"))
        end
      end
    end
  end

  describe "#assign_attributes" do
    let(:new_attributes) { { date_day: "26", date_month: "5", date_year: "2020" } }

    it "assigns the date attributes" do
      question.assign_attributes new_attributes
      expect(question).to have_attributes date_year: "2020", date_month: "5", date_day: "26"
    end

    context "when the attributes are from form input" do
      let(:new_attributes) { { "date(3i)" => "26", "date(2i)" => "5", "date(1i)" => "2020" } }

      it "assigns the date attributes" do
        question.assign_attributes new_attributes
        expect(question).to have_attributes date_year: "2020", date_month: "5", date_day: "26"
      end
    end

    context "when new_attributes is not a hash" do
      let(:new_attributes) { [{ date_day: "26", date_month: "5", date_year: "2020" }] }

      it "raises an error" do
        expect {
          question.assign_attributes new_attributes
        }.to raise_error(
          ArgumentError,
          "When assigning attributes, you must pass a hash as an argument, Array passed.",
        )
      end
    end
  end

  describe "#date_of_birth?" do
    let(:options) { { answer_settings: OpenStruct.new({ input_type: }) } }

    context "when the input type is a date of birth" do
      let(:input_type) { "date_of_birth" }

      it "returns true" do
        expect(question.date_of_birth?).to be true
      end
    end

    context "when the input type is set to other_date" do
      let(:input_type) { "other_date" }

      it "returns false" do
        expect(question.date_of_birth?).to be false
      end
    end

    context "when the input type is not set" do
      let(:input_type) { nil }

      it "returns false" do
        expect(question.date_of_birth?).to be false
      end
    end
  end

private

  def set_date(day, month, year)
    question.date_day = day
    question.date_month = month
    question.date_year = year
  end
end
