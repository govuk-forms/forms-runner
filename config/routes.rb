Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "/auth/govuk_one_login/callback", to: "users/omniauth#callback", as: :omniauth_callback

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "/up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "errors#not_found"

  get "/help/accessibility-statement" => "application#accessibility_statement", as: :accessibility_statement
  get "/help/cookies" => "application#cookies", as: :cookies

  get "/security.txt" => redirect("https://vulnerability-reporting.service.security.gov.uk/.well-known/security.txt")
  get "/submission" => "submission_status#status", as: :status
  get "/.well-known/security.txt" => redirect("https://vulnerability-reporting.service.security.gov.uk/.well-known/security.txt")

  form_id_constraints = { form_id: UrlPatterns::FORM_ID_REGEX }
  form_constraints = {
    **form_id_constraints,
    locale: /(en|cy)/,
    form_slug: UrlPatterns::FORM_SLUG_REGEX,
  }

  # If we make changes to allowed mode values, update the WAF rules first
  scope "/:mode", mode: /preview-draft|preview-archived|preview-live|form/ do
    get "/:form_id" => "forms/base#redirect_to_friendly_url_start", as: :form_id, constraints: form_id_constraints
    scope "/:form_id/:form_slug(.:locale)", constraints: form_constraints do
      get "/" => "forms/base#redirect_to_friendly_url_start", as: :form
      get "/copy-of-answers" => "forms/copy_of_answers#show", as: :copy_of_answers
      post "/copy-of-answers" => "forms/copy_of_answers#save", as: :save_copy_of_answers
      get "/continue-to-login" => "forms/continue_to_one_login#show", as: :continue_to_one_login
      get "/#{CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG}" => "forms/check_your_answers#show", as: :check_your_answers
      post "/#{CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG}" => "forms/check_your_answers#submit_answers", as: :form_submit_answers
      get "/submitted" => "forms/submitted#submitted", as: :form_submitted
      get "/privacy" => "forms/privacy_page#show", as: :form_privacy

      step_constraints = { step_slug: Regexp.union([UrlPatterns::STEP_ID_REGEX_FOR_ROUTES, Regexp.new(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)]) }
      answer_constraints = { answer_index: /\d+/ }
      step_answer_defaults = { answer_index: 1 }

      get "/:step_slug/exit" => "forms/exit_pages#show",
          as: :exit_page,
          constraints: step_constraints

      get "/:step_slug/add-another-answer/change" => "forms/add_another_answer#change",
          as: :change_add_another_answer,
          constraints: step_constraints,
          defaults: { changing_existing_answer: true }
      get "/:step_slug/add-another-answer" => "forms/add_another_answer#show",
          as: :add_another_answer,
          constraints: step_constraints
      post "/:step_slug/add-another-answer" => "forms/add_another_answer#save",
           as: :save_add_another_answer,
           constraints: step_constraints

      # We don't currently support adding another answer for file upload questions, so these routes don't include an
      # `answer_index` param
      get "/:step_slug/review-file" => "forms/review_file#show",
          as: :review_file,
          constraints: step_constraints
      post "/:step_slug/review-file" => "forms/review_file#continue",
           as: :review_file_continue,
           constraints: step_constraints
      get "/:step_slug/remove-file" => "forms/remove_file#show",
          as: :remove_file_confirmation,
          constraints: step_constraints
      delete "/:step_slug/remove-file" => "forms/remove_file#destroy",
             as: :remove_file,
             constraints: step_constraints

      # We don't currently support adding another answer for selection questions, so these routes don't include an
      # `answer_index` param
      get "/:step_slug/none-of-the-above/change" => "forms/selection_none_of_the_above#show",
          as: :change_selection_none_of_the_above,
          constraints: step_constraints,
          defaults: { changing_existing_answer: true }
      get "/:step_slug/none-of-the-above" => "forms/selection_none_of_the_above#show",
          as: :selection_none_of_the_above,
          constraints: step_constraints
      post "/:step_slug/none-of-the-above" => "forms/selection_none_of_the_above#save",
           as: :save_selection_none_of_the_above,
           constraints: step_constraints

      get "/:step_slug/(/:answer_index)/change" => "forms/step#change",
          as: :form_change_answer,
          defaults: step_answer_defaults.merge(changing_existing_answer: true),
          constraints: step_constraints.merge(answer_constraints)
      get "/:step_slug(/:answer_index)" => "forms/step#show",
          as: :form_step,
          constraints: step_constraints.merge(answer_constraints),
          defaults: step_answer_defaults
      post "/:step_slug(/:answer_index)" => "forms/step#save",
           as: :save_form_step,
           constraints: step_constraints,
           defaults: step_answer_defaults

      get "/:step_slug/:answer_index/remove" => "forms/remove_answer#show",
          as: :form_remove_answer,
          constraints: step_constraints.merge(answer_constraints)
      delete "/:step_slug/:answer_index/remove" => "forms/remove_answer#delete",
             as: :delete_form_remove_answer,
             constraints: step_constraints.merge(answer_constraints)

      get "/repeat-submission" => "forms/base#error_repeat_submission", as: :error_repeat_submission, via: :all
    end
  end

  get "/maintenance" => "errors#maintenance", as: :maintenance_page
  get "/404", to: "errors#not_found", as: :error_404, via: :all
  get "/500", to: "errors#internal_server_error", as: :error_500, via: :all
  match "*path", to: "errors#not_found", via: :all
end
