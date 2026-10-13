module Forms
  class SubmittedController < BaseController
    before_action :redirect_to_form_unless_submitted

    def submitted; end

  private

    def redirect_to_form_unless_submitted
      submission_reference = current_context.get_submission_reference

      return if submission_reference.present? && Submission.exists?(reference: submission_reference)

      redirect_to form_path(current_context.form.id, current_context.form.form_slug)
    end
  end
end
