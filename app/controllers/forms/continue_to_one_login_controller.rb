module Forms
  class ContinueToOneLoginController < BaseController
    before_action :redirect_if_feature_disabled, :redirect_if_form_incomplete

    def show
      return_from_one_login_store.store_return_params(
        form: current_context.form,
        mode: mode,
        locale: locale_param,
      )
    end

  private

    def redirect_if_feature_disabled
      return if FeatureService.enabled?(:filler_answer_email_enabled)

      redirect_to check_your_answers_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug)
    end

    def redirect_if_form_incomplete
      return if current_context.can_visit?(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)
    end
  end
end
