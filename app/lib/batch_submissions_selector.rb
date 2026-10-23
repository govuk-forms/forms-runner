class BatchSubmissionsSelector
  Batch = Data.define(:form_id, :mode, :submissions)

  class << self
    def daily_batches(date)
      Enumerator.new do |yielder|
        form_ids_and_modes_with_send_daily_submission_batch(date).each do |form_id, mode|
          submissions = Submission.for_form_and_mode(form_id, mode).on_day(date).order(created_at: :desc)

          yielder << Batch.new(form_id, mode, submissions)
        end
      end
    end

    def weekly_batches(time_in_week)
      Enumerator.new do |yielder|
        form_ids_and_modes_with_send_weekly_submission_batch(time_in_week).each do |form_id, mode|
          submissions = Submission.for_form_and_mode(form_id, mode).in_week(time_in_week).order(created_at: :desc)

          yielder << Batch.new(form_id, mode, submissions)
        end
      end
    end

  private

    def form_ids_and_modes_with_send_daily_submission_batch(date)
      Submission.on_day(date)
                .distinct
                .pluck(:form_id, :mode)
                .filter { |form_id, mode| form_has_delivery_schedule?(form_id, mode, form_ids_and_states_with_daily_submission) }
    end

    def form_ids_and_modes_with_send_weekly_submission_batch(begin_at)
      Submission.in_week(begin_at)
                .distinct
                .pluck(:form_id, :mode)
                .filter { |form_id, mode| form_has_delivery_schedule?(form_id, mode, form_ids_and_states_with_weekly_submission) }
    end

    def form_has_delivery_schedule?(form_id, mode, forms_with_delivery_schedule)
      state = Mode.new(mode).preview_draft? ? "draft" : "current"

      { form_id:, state: }.in?(forms_with_delivery_schedule)
    end

    def form_ids_and_states_with_daily_submission
      Api::V3::FormDocumentResource.forms_with_delivery_schedule("daily")
    end

    def form_ids_and_states_with_weekly_submission
      Api::V3::FormDocumentResource.forms_with_delivery_schedule("weekly")
    end
  end
end
