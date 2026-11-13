require "rails_helper"

feature "Continue a saved form", type: :feature do
  let(:first_question_text) { "What is your name?" }
  let(:second_question_text) { "What is your quest?" }

  let(:steps) do
    [
      build(:question_step, :with_text_settings, id: 1, next_step_id: 2, question_text: first_question_text),
      build(:question_step, :with_text_settings, id: 2, question_text: second_question_text),
    ]
  end

  let(:form) do
    build(:form_document, :live, form_id: 1, name: "Apply for a juggling licence", steps:, start_page: 1, save_and_return: "enabled")
  end

  let(:req_headers) { { "Accept" => "application/json" } }

  let(:one_login_sub) { "user-sub-abc" }
  let(:one_login_email) { "filler@example.com" }
  let(:id_token) { JWT.encode({ iat: Time.current.to_i }, nil, "none") }
  let(:auth_hash) do
    {
      provider: :govuk_one_login,
      uid: one_login_sub,
      info: { email: one_login_email },
      credentials: { id_token: },
    }
  end

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/1/live", req_headers, form.to_json, 200
    end

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:default] = OmniAuth::AuthHash.new(auth_hash)
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:default] = nil
  end

  scenario "As a form filler, I sign in with GOV.UK One Login to continue filling in my saved form" do
    given_i_have_saved_progress_for_the_form

    when_i_visit_the_form_start_page
    and_i_choose_to_continue_filling_in_a_saved_form
    then_i_see_the_sign_in_interstitial

    when_i_continue_to_one_login
    then_i_see_the_first_question_with_my_saved_answer

    when_i_continue_to_the_next_question
    then_i_see_the_second_question
  end

  scenario "As a form filler with no saved form, I can start a new form instead" do
    when_i_visit_the_form_start_page
    and_i_choose_to_continue_filling_in_a_saved_form
    and_i_continue_to_one_login
    then_i_see_that_my_saved_form_could_not_be_found

    when_i_choose_to_start_a_new_form
    then_i_see_the_first_question_with_no_answer
  end

  scenario "As a form filler, I choose to start a new form" do
    when_i_visit_the_form_start_page
    and_i_choose_to_start_a_new_form
    then_i_see_the_first_question_with_no_answer
  end

  scenario "As a form filler who has already answered some questions, I choose to start a new form" do
    given_i_have_answered_the_first_question

    when_i_visit_the_form_start_page
    and_i_choose_to_start_a_new_form
    then_i_see_the_first_question_with_no_answer
  end

  def given_i_have_saved_progress_for_the_form
    create(:incomplete_submission,
           user_id: one_login_sub,
           form_id: 1,
           form_version: form.version,
           answers: { "1" => { "text" => "Sir Lancelot" } })
  end

  def given_i_have_answered_the_first_question
    visit form_step_path(mode: "form", form_id: 1, form_slug: form.form_slug, step_slug: 1)
    fill_in first_question_text, with: "Sir Robin"
    click_button "Continue"
    expect(page.find("h1")).to have_text second_question_text
  end

  def when_i_visit_the_form_start_page
    visit form_path(mode: "form", form_id: 1, form_slug: form.form_slug)
    expect(page.find("h1")).to have_text "What do you want to do?"
  end

  def and_i_choose_to_continue_filling_in_a_saved_form
    choose "Continue filling in a saved form"
    click_button "Continue"
  end

  def and_i_choose_to_start_a_new_form
    choose "Start a new form"
    click_button "Continue"
  end

  def then_i_see_the_sign_in_interstitial
    expect(page.find("h1")).to have_text "Sign in to your GOV.UK One Login"
    expect(page).to have_button "Continue to GOV.UK One Login"
  end

  def when_i_continue_to_one_login
    click_button "Continue to GOV.UK One Login"
  end

  alias_method :and_i_continue_to_one_login, :when_i_continue_to_one_login

  def then_i_see_the_first_question_with_my_saved_answer
    expect(page.find("h1")).to have_text first_question_text
    expect(page).to have_field(first_question_text, with: "Sir Lancelot")
  end

  def when_i_continue_to_the_next_question
    click_button "Continue"
  end

  def then_i_see_the_second_question
    expect(page.find("h1")).to have_text second_question_text
  end

  def then_i_see_that_my_saved_form_could_not_be_found
    expect(page.find("h1")).to have_text "We could not find your saved form"
  end

  def when_i_choose_to_start_a_new_form
    click_link "Start a new form"
  end

  def then_i_see_the_first_question_with_no_answer
    expect(page.find("h1")).to have_text first_question_text
    expect(page).to have_field(first_question_text, with: "")
  end
end
