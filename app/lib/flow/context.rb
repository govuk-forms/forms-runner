module Flow
  class Context
    attr_reader :form, :journey

    def initialize(form:, store:)
      @form = form
      @answer_store = Store::SessionAnswerStore.new(store, form.id)
      @confirmation_details_store = Store::ConfirmationDetailsStore.new(store, form.id)
      @journey = Journey.new(answer_store: @answer_store, form:)
    end

    delegate :support_details, to: :form
    delegate :step_by_id, :previous_step, :next_step_slug, :next_step, :can_visit?, :completed_steps, :all_steps, to: :journey
    delegate :clear_stored_answer, :clear, :form_submitted?, :answers, :locales_used, to: :answer_store
    delegate :save_submission_details, :get_submission_reference, :requested_email_confirmation?, :clear_submission_details, :save_copy_of_answers_preference, :wants_copy_of_answers?, to: :confirmation_details_store

    def save_step(step, locale: :en, context: nil)
      return false unless step.valid?(context)

      answer_store.add_locale(locale)
      step.save_to_store(answer_store)
    end

  private

    attr_reader :answer_store, :confirmation_details_store
  end
end
