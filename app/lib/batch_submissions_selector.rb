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
                .order(created_at: :asc)
                .pluck(:form_id, :mode)
                .uniq
                .filter { |form_id, mode| form_has_delivery_configurations_with_schedule?(form_id, mode, "daily") }
    end

    def form_ids_and_modes_with_send_weekly_submission_batch(begin_at)
      Submission.in_week(begin_at)
                .order(created_at: :asc)
                .pluck(:form_id, :mode)
                .uniq
                .filter { |form_id, mode| form_has_delivery_configurations_with_schedule?(form_id, mode, "weekly") }
    end

    def form_has_delivery_configurations_with_schedule?(form_id, mode, schedule)
      delivery_configurations = Api::DeliveryConfigurationResource.from_form(form_id, draft: Mode.new(mode).preview_draft?)

      delivery_configurations.any? { it.delivery_schedule == schedule }
    end
  end
end
