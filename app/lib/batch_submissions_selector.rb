class BatchSubmissionsSelector
  Batch = Data.define(:form_id, :mode, :submissions)

  class << self
    def daily_batches(date)
      Enumerator.new do |yielder|
        form_ids_and_modes_with_send_daily_submission_batch(date).each do |form_id, mode|
          submissions = Submission.for_form_and_mode(form_id, mode).on_day(date).order(created_at: :desc)

          # If the send_daily_submission_batch is true for the most recent submission, include all submissions on that
          # day in the batch. If it is false do not return a batch for any of the submissions on that day.
          next unless submissions.any? && submissions.first.form_document["send_daily_submission_batch"] == true

          yielder << Batch.new(form_id, mode, submissions)
        end
      end
    end

    def weekly_batches(time_in_week)
      Enumerator.new do |yielder|
        form_ids_and_modes_with_send_weekly_submission_batch(time_in_week).each do |form_id, mode|
          submissions = Submission.for_form_and_mode(form_id, mode).in_week(time_in_week).order(created_at: :desc)

          # If the send_weekly_submission_batch is true for the most recent submission, include all submissions in that
          # week in the batch. If it is false do not return a batch for any of the submissions in that week.
          next unless submissions.any? && submissions.first.form_document["send_weekly_submission_batch"] == true

          yielder << Batch.new(form_id, mode, submissions)
        end
      end
    end

  private

    def form_ids_and_modes_with_send_daily_submission_batch(date)
      # Get all form_ids and modes that have at least one submission on the date with send_daily_submission_batch
      # set to true.
      Submission.on_day(date)
                .where("(form_document->>'send_daily_submission_batch')::boolean = true")
                .distinct
                .pluck(:form_id, :mode)
    end

    def form_ids_and_modes_with_send_weekly_submission_batch(begin_at)
      # Get all form_ids and modes that have at least one submission in the week with send_weekly_submission_batch
      # set to true.
      Submission.in_week(begin_at)
                .where("(form_document->>'send_weekly_submission_batch')::boolean = true")
                .distinct
                .pluck(:form_id, :mode)
    end
  end
end
