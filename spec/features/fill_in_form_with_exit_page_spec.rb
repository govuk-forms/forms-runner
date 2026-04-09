require "rails_helper"

feature "Fill in and submit a form with an exit page", type: :feature do
  let(:routing_conditions) { [DataStruct.new(routing_page_id: 1, check_page_id: 1, answer_value: "Option 1", goto_page_id: nil, exit_page_heading: "This is an exit_page", exit_page_markdown: "This is the contents", validation_errors: [])] }
  let(:steps) { [build(:v2_selection_question_step, id: 1, routing_conditions:, question_text:)] }
  let(:form) { build :v2_form_document, :live, form_id: 1, name: "Fill in this form", steps:, start_page: 1 }
  let(:question_text) { Faker::Lorem.question }
  let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }

  let(:req_headers) { { "Accept" => "application/json" } }
  let(:post_headers) { { "Content-Type" => "application/json" } }

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/1/live", req_headers, form.to_json, 200
    end

    allow(ReferenceNumberService).to receive(:generate).and_return(reference)
    allow(FeatureService).to receive(:enabled?).with("filler_answer_email_enabled").and_return(true)
  end

  scenario "As a form filler" do
    when_i_visit_the_form_start_page
    then_i_should_see_the_first_question

    when_i_choose_the_exit_option
    and_i_click_on_continue
    then_i_should_see_the_exit_page

    when_i_click_back
    when_i_dont_choose_the_exit_option
    and_i_click_on_continue
    then_i_should_see_the_copy_of_answers_page

    when_i_choose_not_to_receive_a_copy
    and_i_click_on_continue
    then_i_should_see_the_check_your_answers_page

    when_i_opt_out_of_email_confirmation
    and_i_submit_my_form
    then_my_form_should_be_submitted
    and_i_should_receive_a_reference_number
  end

  def when_i_visit_the_form_start_page
    visit form_path(mode: "form", form_id: 1, form_slug: "fill-in-this-form")
    expect_page_to_have_no_axe_errors(page)
  end

  def then_i_should_see_the_first_question
    expect(page.find("h1")).to have_text question_text
  end

  def when_i_choose_the_exit_option
    choose "Option 1"
  end

  def when_i_dont_choose_the_exit_option
    choose "Option 2"
  end

  def and_i_click_on_continue
    click_button "Continue"
  end

  def then_i_should_see_the_copy_of_answers_page
    expect(page.find("h1")).to have_text "Do you want to get an email with a copy of your answers?"
    expect_page_to_have_no_axe_errors(page)
  end

  def when_i_choose_not_to_receive_a_copy
    choose "No"
  end

  def then_i_should_see_the_check_your_answers_page
    expect(page.find("h1")).to have_text "Check your answers before submitting your form"
    expect(page).to have_text question_text
    expect(page).to have_text "Option 2"
    expect_page_to_have_no_axe_errors(page)
  end

  def when_i_click_back
    click_on "Back"
  end

  def then_i_should_see_the_exit_page
    expect(page.find("h1")).to have_text "This is an exit_page"
    expect(page).to have_text "This is the contents"
    expect_page_to_have_no_axe_errors(page)
  end

  def when_i_opt_out_of_email_confirmation
    choose "No"
  end

  def and_i_submit_my_form
    click_on "Submit"
  end

  def then_my_form_should_be_submitted
    expect(page.find("h1")).to have_text "Your form has been submitted"
    expect_page_to_have_no_axe_errors(page)
  end

  def and_i_should_receive_a_reference_number
    expect(page).to have_text reference
  end
end
