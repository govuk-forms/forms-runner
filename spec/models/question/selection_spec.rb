require "rails_helper"

RSpec.describe Question::Selection, type: :model do
  subject(:question) { build :selection, only_one_option:, selection_options:, is_optional:, question_text: }

  # For an English form the name and value are the same, for Welsh forms they would be different.
  # For form translations the name is the text in the current locale, but the value is always equal
  # to the name in the English form, i.e. the value doesn't change between locales.
  # The name is rendered for form fillers, but the value is stored.
  # For form processors we always want to show the English text, but we use the English form document
  # when generating submssions so the behaviour with the Welsh translation shouldn't matter.
  let(:selection_options) { cy_selection_options }
  let(:en_selection_options) { [OpenStruct.new({ name: "Option 1", value: "Option 1" }), OpenStruct.new({ name: "Option 2", value: "Option 2" })] }
  let(:cy_selection_options) { [OpenStruct.new({ name: "Opsiwn 1", value: "Option 1" }), OpenStruct.new({ name: "Opsiwn 2", value: "Option 2" })] }

  let(:is_optional) { false }
  let(:only_one_option) { "false" }
  let(:question_text) { Faker::Lorem.question }

  context "when the selection question is a checkbox" do
    let(:only_one_option) { "false" }
    let(:is_optional) { false }

    it_behaves_like "a question model"

    context "when created without attributes" do
      it "returns invalid" do
        expect(question).not_to be_valid
        expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.checkbox_blank"))
      end

      it "shows as a blank string" do
        expect(question.show_answer).to eq ""
      end

      it "returns a hash with an blank value for show_answer_in_csv" do
        expect(question.show_answer_in_csv).to eq(Hash[question_text, ""])
      end

      it "returns a hash with blank values for show_answer_in_json" do
        expect(question.show_answer_in_json).to eq({
          selections: [],
          answer_text: "",
        })
      end
    end

    context "when selection is blank" do
      before do
        question.selection = [""]
      end

      it "returns invalid" do
        expect(question).not_to be_valid
        expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.checkbox_blank"))
      end

      it "shows as a blank string" do
        expect(question.show_answer).to eq ""
      end

      it "returns a hash with an blank value for show_answer_in_csv" do
        expect(question.show_answer_in_csv).to eq(Hash[question_text, ""])
      end

      it "returns a hash with blank values for show_answer_in_json" do
        expect(question.show_answer_in_json).to eq({
          selections: [],
          answer_text: "",
        })
      end
    end

    context "when selection has a value" do
      before do
        question.selection = ["Option 1"]
      end

      it "shows the answer" do
        expect(question.show_answer).to eq("Opsiwn 1")
      end

      context "when creating a submission for a form processor" do
        let(:selection_options) { en_selection_options }

        it "shows the answer" do
          expect(question.show_answer).to eq("Option 1")
        end

        it "shows the answer in show_answer_in_csv" do
          expect(question.show_answer_in_csv).to eq(Hash[question_text, "Option 1"])
        end

        it "returns a hash for show_answer_in_json" do
          expect(question.show_answer_in_json).to eq({
            selections: ["Option 1"],
            answer_text: "Option 1",
          })
        end
      end
    end

    it "returns invalid when selection is not one of the options" do
      question.selection = ["Option 1000"]
      expect(question).not_to be_valid
      expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.inclusion"))
    end

    it "returns valid with one item selected" do
      question.selection = ["Option 1"]
      expect(question).to be_valid
      expect(question.errors[:selection]).to be_empty
    end

    it "returns valid with two items selected" do
      question.selection = ["Option 1", "Option 2"]
      expect(question).to be_valid
      expect(question.errors[:selection]).to be_empty
    end

    it "calculates allow_multiple_answers correctly" do
      expect(question.allow_multiple_answers?).to be true
    end

    context "when question is optional" do
      let(:is_optional) { true }

      context "when selection is blank" do
        before do
          question.selection = [""]
        end

        it "returns invalid with blank selection" do
          expect(question).not_to be_valid
          expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.both_none_and_value_selected"))
        end

        it "shows as a blank string" do
          expect(question.show_answer).to eq ""
        end

        it "returns a hash with an blank value for show_answer_in_csv" do
          expect(question.show_answer_in_csv).to eq(Hash[question_text, ""])
        end

        it "returns a hash with blank values for show_answer_in_json" do
          expect(question.show_answer_in_json).to eq({
            selections: [],
            answer_text: "",
          })
        end
      end

      it "returns valid with none of the above selected" do
        question.selection = [Question::Selection::NONE_OF_THE_ABOVE_VALUE]
        expect(question).to be_valid
        expect(question.errors[:selection]).to be_empty
      end

      it "returns invalid with both an item and none selected" do
        question.selection = ["Option 1", Question::Selection::NONE_OF_THE_ABOVE_VALUE]
        expect(question).not_to be_valid
        expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.both_none_and_value_selected"))
      end

      it "does not include '(optional)' in the question text" do
        expect(question.question_text_with_optional_suffix).to eq(question.question_text)
      end

      context "when selection has a value" do
        before do
          question.selection = ["Option 1"]
        end

        it "shows the answer" do
          expect(question.show_answer).to eq("Opsiwn 1")
        end

        context "when creating a submission for a form processor" do
          let(:selection_options) { en_selection_options }

          it "shows the answer" do
            expect(question.show_answer).to eq("Option 1")
          end

          it "shows the answer in show_answer_in_csv" do
            expect(question.show_answer_in_csv).to eq(Hash[question_text, "Option 1"])
          end

          it "returns a hash for show_answer_in_json" do
            expect(question.show_answer_in_json).to eq({
              selections: ["Option 1"],
              answer_text: "Option 1",
            })
          end
        end
      end
    end
  end

  context "when the selection question is a radio button" do
    let(:only_one_option) { "true" }
    let(:is_optional) { false }

    before do
      question.selection = ""
    end

    it_behaves_like "a question model"

    context "when selection is blank" do
      before do
        question.selection = ""
      end

      it "returns invalid" do
        expect(question).not_to be_valid
        expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.blank"))
      end

      it "shows as a blank string" do
        expect(question.show_answer).to eq ""
      end

      it "returns a hash with an blank value for show_answer_in_csv" do
        expect(question.show_answer_in_csv).to eq(Hash[question_text, ""])
      end

      it "returns a hash with blank values for show_answer_in_json" do
        expect(question.show_answer_in_json).to eq({
          answer_text: "",
        })
      end
    end

    context "when selection has a value" do
      before do
        question.selection = "Option 1"
      end

      it "shows the answer" do
        expect(question.show_answer).to eq("Opsiwn 1")
      end

      context "when creting a submission for a form form processor" do
        let(:selection_options) { en_selection_options }

        it "shows the answer" do
          expect(question.show_answer).to eq("Option 1")
        end

        it "shows the answer in show_answer_in_csv" do
          expect(question.show_answer_in_csv).to eq(Hash[question_text, "Option 1"])
        end

        it "returns a hash for show_answer_in_json" do
          expect(question.show_answer_in_json).to eq({
            answer_text: "Option 1",
          })
        end
      end
    end

    it "returns invalid when selection is not one of the options" do
      question.selection = "Option 1000"
      expect(question).not_to be_valid
      expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.inclusion"))
    end

    it "returns valid with one item selected" do
      question.selection = "Option 1"
      expect(question).to be_valid
      expect(question.errors[:selection]).to be_empty
    end

    it "calculates allow_multiple_answers correctly" do
      expect(question.allow_multiple_answers?).to be false
    end

    context "when question is optional" do
      let(:is_optional) { true }

      it "returns valid with none of the above selected" do
        question.selection = Question::Selection::NONE_OF_THE_ABOVE_VALUE
        expect(question).to be_valid
        expect(question.errors[:selection]).to be_empty
      end

      context "when selection is blank" do
        before do
          question.selection = ""
        end

        it "returns invalid" do
          expect(question).not_to be_valid
          expect(question.errors[:selection]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.selection.blank"))
        end

        it "shows as a blank string" do
          expect(question.show_answer).to eq ""
        end

        it "returns a hash with an blank value for show_answer_in_csv" do
          expect(question.show_answer_in_csv).to eq(Hash[question_text, ""])
        end

        it "returns a hash with blank values for show_answer_in_json" do
          expect(question.show_answer_in_json).to eq({
            answer_text: "",
          })
        end
      end

      context "when selection has a value" do
        before do
          question.selection = "Option 1"
        end

        it "shows the answer" do
          expect(question.show_answer).to eq("Opsiwn 1")
        end

        context "when creating a submission for a form processor" do
          let(:selection_options) { en_selection_options }

          it "shows the answer" do
            expect(question.show_answer).to eq("Option 1")
          end

          it "shows the answer in show_answer_in_csv" do
            expect(question.show_answer_in_csv).to eq(Hash[question_text, "Option 1"])
          end

          it "returns a hash for show_answer_in_json" do
            expect(question.show_answer_in_json).to eq({
              answer_text: "Option 1",
            })
          end
        end
      end
    end
  end

  context "when there is a none of the above question configured" do
    subject(:question) do
      build(:selection, :with_none_of_the_above_question, only_one_option:, selection_options:, is_optional:,
                                                          none_of_the_above_question_is_optional:)
    end

    let(:is_optional) { true }
    let(:none_of_the_above_question_is_optional) { "true" }

    context "when there fewer than 31 selection options" do
      context "when only_one_option is false" do
        let(:only_one_option) { "false" }

        context "when none_of_the_above_question is optional" do
          context "when 'None of the above' is selected" do
            before do
              question.selection = [Question::Selection::NONE_OF_THE_ABOVE_VALUE]
            end

            it "is valid when there is no none_of_the_above_answer" do
              expect(question).to be_valid
              expect(question.errors[:none_of_the_above_answer]).to be_empty
            end

            it "is invalid when the none_of_the_above answer is too long" do
              question.none_of_the_above_answer = "a" * 500
              expect(question).not_to be_valid
              expect(question.errors[:none_of_the_above_answer]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.none_of_the_above_answer.too_long"))
            end

            context "when creating a submission for a form processor" do
              let(:selection_options) { en_selection_options }

              context "when a different option has been entered" do
                before do
                  question.none_of_the_above_answer = "Some answer"
                end

                it "shows the none of the above answer as part of #show_answer_in_csv" do
                  expect(question.show_answer_in_csv).to eq(Hash[question.question_text, "None of the above - Some answer"])
                end

                it "returns a hash with the none of the above answer for show_answer_in_json" do
                  expect(question.show_answer_in_json).to eq({
                    selections: ["None of the above"],
                    none_of_the_above_answer: "Some answer",
                    answer_text: "None of the above - Some answer",
                  })
                end
              end

              context "when a different option has not been entered" do
                before do
                  question.none_of_the_above_answer = ""
                end

                it "is blank where the none of the above answer would be as part of #show_answer_in_csv" do
                  expect(question.show_answer_in_csv).to eq(Hash[question.question_text, "None of the above - "])
                end

                it "returns a hash with 'None of the above' for show_answer_in_json" do
                  expect(question.show_answer_in_json).to eq({
                    selections: ["None of the above"],
                    none_of_the_above_answer: "",
                    answer_text: "None of the above - ",
                  })
                end
              end
            end
          end

          context "when 'None of the above' is not selected" do
            before do
              question.selection = ["Option 1"]
            end

            it "clears the none_of_the_above_answer before validating" do
              question.none_of_the_above_answer = "Some answer"
              expect(question).to be_valid
              expect(question.none_of_the_above_answer).to be_nil
            end

            context "when creating a submission for a form processor" do
              let(:selection_options) { en_selection_options }

              it "returns a hash without the none of the above answer for show_answer_in_json" do
                expect(question.show_answer_in_json).to eq({
                  selections: ["Option 1"],
                  answer_text: "Option 1",
                })
              end
            end
          end
        end

        context "when none_of_the_above_question is mandatory" do
          let(:none_of_the_above_question_is_optional) { "false" }

          context "when 'None of the above' is selected" do
            before do
              question.selection = [Question::Selection::NONE_OF_THE_ABOVE_VALUE]
            end

            it "is invalid when there is no none_of_the_above_answer" do
              expect(question).not_to be_valid
              expect(question.errors[:none_of_the_above_answer]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.none_of_the_above_answer.blank"))
            end

            it "is valid when there is a none_of_the_above_answer" do
              question.none_of_the_above_answer = "Some answer"
              expect(question).to be_valid
              expect(question.errors[:none_of_the_above_answer]).to be_empty
              expect(question.none_of_the_above_answer).to eq("Some answer")
            end

            context "when creating a submission for a form processor" do
              let(:selection_options) { en_selection_options }

              it "returns a hash with the none of the above answer for show_answer_in_json" do
                question.none_of_the_above_answer = "Some answer"
                expect(question.show_answer_in_json).to eq({
                  selections: ["None of the above"],
                  none_of_the_above_answer: "Some answer",
                  answer_text: "None of the above - Some answer",
                })
              end
            end
          end

          context "when 'None of the above' is not selected" do
            before do
              question.selection = ["Option 1"]
            end

            it "is valid when there is no none_of_the_above_answer" do
              expect(question).to be_valid
              expect(question.errors[:none_of_the_above_answer]).to be_empty
            end

            it "is valid when there is a none_of_the_above_answer that is too long" do
              question.none_of_the_above_answer = "a" * 500
              expect(question).to be_valid
              expect(question.errors[:none_of_the_above_answer]).to be_empty
            end

            it "clears the none_of_the_above_answer before validating" do
              question.none_of_the_above_answer = "Some answer"
              expect(question).to be_valid
              expect(question.none_of_the_above_answer).to be_nil
            end

            context "when creating a submission for a form processor" do
              let(:selection_options) { en_selection_options }

              it "returns a hash without the none of the above answer for show_answer_in_json" do
                expect(question.show_answer_in_json).to eq({
                  selections: ["Option 1"],
                  answer_text: "Option 1",
                })
              end
            end
          end
        end
      end

      context "when only_one_option is true" do
        let(:only_one_option) { "true" }
        let(:none_of_the_above_question_is_optional) { "false" }

        context "when 'None of the above' is selected" do
          before do
            question.selection = Question::Selection::NONE_OF_THE_ABOVE_VALUE
          end

          it "is invalid when there is no none_of_the_above_answer" do
            expect(question).not_to be_valid
            expect(question.errors[:none_of_the_above_answer]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.none_of_the_above_answer.blank"))
          end

          it "is invalid when the none_of_the_above answer is too long" do
            question.none_of_the_above_answer = "a" * 500
            expect(question).not_to be_valid
            expect(question.errors[:none_of_the_above_answer]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.none_of_the_above_answer.too_long"))
          end

          context "when creating a submission for a form processor" do
            let(:selection_options) { en_selection_options }

            it "returns a hash with 'None of the above' for show_answer_in_json" do
              question.none_of_the_above_answer = "something else"
              expect(question.show_answer_in_json).to eq({
                selection: "None of the above",
                none_of_the_above_answer: "something else",
                answer_text: "None of the above - something else",
              })
            end
          end
        end

        context "when 'None of the above' is not selected" do
          before do
            question.selection = "Option 1"
          end

          it "is valid when there is no none_of_the_above_answer" do
            expect(question).to be_valid
            expect(question.errors[:none_of_the_above_answer]).to be_empty
          end

          it "is valid when there is a none_of_the_above_answer that is too long" do
            question.none_of_the_above_answer = "a" * 500
            expect(question).to be_valid
            expect(question.errors[:none_of_the_above_answer]).to be_empty
          end

          context "when creating a submission for a form processor" do
            let(:selection_options) { en_selection_options }

            it "returns a hash without the none of the above answer for show_answer_in_json" do
              expect(question.show_answer_in_json).to eq({
                selection: "Option 1",
                answer_text: "Option 1",
              })
            end
          end
        end
      end
    end

    context "when there are more than 30 selection options and none of the above is selected" do
      let(:selection_options) { Array.new(31).map { |i| OpenStruct.new(name: "Option #{i}", value: "Option #{i}") } }
      let(:none_of_the_above_question_is_optional) { "false" }

      before do
        question.with_none_of_the_above_selected
      end

      it "does not validate the none_of_the_above_answer when the validation context is skip_none_of_the_above_question_validation" do
        expect(question.valid?(:skip_none_of_the_above_question_validation)).to be true
        expect(question.errors[:none_of_the_above_answer]).to be_empty
      end

      it "validates the none_of_the_above_answer when there is no validation context" do
        expect(question).to be_invalid
        expect(question.errors[:none_of_the_above_answer]).to include(I18n.t("activemodel.errors.models.question/selection.attributes.none_of_the_above_answer.blank"))
      end

      context "when the none of the above question is optional" do
        let(:none_of_the_above_question_is_optional) { "true" }

        it "is valid when the none_of_the_above_answer is not present in the none_of_the_above_page context" do
          expect(question.valid?(:none_of_the_above_page)).to be true
          expect(question.errors[:none_of_the_above_answer]).to be_empty
        end
      end
    end
  end

  describe "#answered?" do
    context "when there is a none of the above question configured" do
      subject(:question) do
        build(:single_selection_question,
              :with_none_of_the_above_question,
              selection_options:,
              none_of_the_above_question_is_optional: "true",
              selection:)
      end

      context "when 'None of the above' is selected" do
        let(:selection) { Question::Selection::NONE_OF_THE_ABOVE_VALUE }

        it "returns false when no none_of_the_above_answer is present" do
          question.none_of_the_above_answer = nil
          expect(question.answered?).to be false
        end

        it "returns true when a none_of_the_above_answer is present" do
          question.none_of_the_above_answer = "Some answer"
          expect(question.answered?).to be true
        end

        it "returns true when a none_of_the_above_answer is present and blank" do
          question.none_of_the_above_answer = ""
          expect(question.answered?).to be true
        end
      end

      context "when 'None of the above' is not selected" do
        context "when an answer is present" do
          let(:selection) { "Option 1" }

          it "returns true" do
            expect(question.answered?).to be true
          end
        end

        context "when an answer is not present" do
          let(:selection) { nil }

          it "returns false" do
            expect(question.answered?).to be false
          end
        end
      end
    end

    context "when there is no none of the above question configured" do
      subject(:question) do
        build(:single_selection_question, selection_options:, selection:)
      end

      context "when 'None of the above' is selected" do
        let(:selection) { Question::Selection::NONE_OF_THE_ABOVE_VALUE }

        it "returns true" do
          expect(question.answered?).to be true
        end
      end
    end
  end

  describe "#selection_options_with_none_of_the_above" do
    let(:only_one_option) { "true" }
    let(:none_of_the_above_option) { OpenStruct.new(name: I18n.t("page.none_of_the_above"), value: Question::Selection::NONE_OF_THE_ABOVE_VALUE) }

    context "when the user can select 'None of the above'" do
      let(:is_optional) { true }

      it "includes the selection options" do
        question.answer_settings.selection_options.each do |option|
          expect(question.selection_options_with_none_of_the_above).to include(option)
        end
      end

      it "includes 'None of the above'" do
        expect(question.selection_options_with_none_of_the_above).to include(none_of_the_above_option)
      end
    end

    context "when the user cannot select 'None of the above'" do
      let(:is_optional) { false }

      it "includes the selection options" do
        question.answer_settings.selection_options.each do |option|
          expect(question.selection_options_with_none_of_the_above).to include(option)
        end
      end

      it "does not include 'None of the above'" do
        expect(question.selection_options_with_none_of_the_above).not_to include(none_of_the_above_option)
      end
    end
  end

  describe "#autocomplete_component?" do
    context "when there are 30 selection options" do
      let(:selection_options) { Array.new(30).map { |_index| OpenStruct.new(name: Faker::Lorem.sentence, value: Faker::Lorem.sentence) } }

      it "returns false" do
        expect(question.autocomplete_component?).to be false
      end
    end

    context "when there are more than 30 selection options" do
      let(:selection_options) { Array.new(31).map { |_index| OpenStruct.new(name: Faker::Lorem.sentence, value: Faker::Lorem.sentence) } }

      it "returns true" do
        expect(question.autocomplete_component?).to be true
      end
    end
  end

  describe "#has_none_of_the_above_question?" do
    let(:is_optional) { true }

    context "when there is a none of the above question configured" do
      subject(:question) do
        build(:selection,
              :with_none_of_the_above_question,
              only_one_option:,
              selection_options:,
              is_optional:,
              none_of_the_above_question_is_optional:)
      end

      let(:none_of_the_above_question_is_optional) { "true" }

      it "returns true" do
        expect(question.has_none_of_the_above_question?).to be true
      end

      context "when the question is not optional" do
        let(:is_optional) { false }

        it "returns false" do
          expect(question.has_none_of_the_above_question?).to be false
        end
      end
    end

    context "when there is no none of the above question configured" do
      it "returns false" do
        expect(question.has_none_of_the_above_question?).to be false
      end
    end

    context "when the none_of_the_above_question has no question_text" do
      subject(:question) do
        build(:selection,
              is_optional:,
              only_one_option:,
              selection_options:,
              none_of_the_above_question: Struct.new)
      end

      it "returns false" do
        expect(question.has_none_of_the_above_question?).to be false
      end
    end
  end
end
