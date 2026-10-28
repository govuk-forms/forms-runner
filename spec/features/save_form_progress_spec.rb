require "rails_helper"

feature "Save form progress", type: :feature do
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

  scenario "As a form filler, I sign in with GOV.UK One Login to save my progress" do
    when_i_visit_the_first_question
    and_i_answer_the_first_question
    then_i_see_the_save_and_exit_link

    when_i_click_save_and_exit
    then_i_see_the_sign_in_interstitial

    when_i_continue_to_one_login
    then_i_see_the_confirmation_page
    and_my_answers_are_saved
  end

  def when_i_visit_the_first_question
    visit form_step_path(mode: "form", form_id: 1, form_slug: form.form_slug, step_slug: 1)
    expect(page.find("h1")).to have_text first_question_text
  end

  def and_i_answer_the_first_question
    fill_in first_question_text, with: "Sir Lancelot"
    click_button "Continue"
    expect(page.find("h1")).to have_text second_question_text
  end

  def then_i_see_the_save_and_exit_link
    expect(page).to have_link("Save and exit")
  end

  def when_i_click_save_and_exit
    click_link "Save and exit"
  end

  def then_i_see_the_sign_in_interstitial
    expect(page.find("h1")).to have_text "Use GOV.UK One Login to save your progress"
    expect(page).to have_button "Continue to GOV.UK One Login"
    expect(page).to have_no_link "Sign in with a different GOV.UK One Login"
  end

  def when_i_continue_to_one_login
    click_button "Continue to GOV.UK One Login"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_css(".govuk-notification-banner--success", text: "Your form has been saved")
    expect(page).to have_link "Sign out of GOV.UK One Login"
  end

  def and_my_answers_are_saved
    incomplete_submission = IncompleteSubmission.find_by(user_id: one_login_sub, form_id: 1)

    expect(incomplete_submission).to be_present
    expect(incomplete_submission.answers).to eq("1" => { "text" => "Sir Lancelot" })
  end
end
