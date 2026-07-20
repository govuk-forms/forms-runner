class BatchSubmissionsSelector
  Batch = Data.define(:form_id, :mode, :submissions)

  # TODO: we can remove checking the send_daily_submission_batch and send_weekly_submission_batch in September 2026
  # when all Submissions without delivery_configurations on the form document have been deleted.
  DAILY_BATCH_FORM_DOCUMENT_CONDITION = <<~SQL.squish
    (form_document->>'send_daily_submission_batch')::boolean = true
    OR form_document->'delivery_configurations' @> '[{"delivery_schedule":"daily"}]'::jsonb
  SQL
  WEEKLY_BATCH_FORM_DOCUMENT_CONDITION = <<~SQL.squish
    (form_document->>'send_weekly_submission_batch')::boolean = true
    OR form_document->'delivery_configurations' @> '[{"delivery_schedule":"weekly"}]'::jsonb
  SQL

  class << self
    def daily_batches(date)
      Enumerator.new do |yielder|
        form_ids_and_modes_with_send_daily_submission_batch(date).each do |form_id, mode|
          submissions = Submission.for_form_and_mode(form_id, mode).on_day(date).order(created_at: :desc)

          # If the most recent submission is configured for daily batching, include all submissions on that day in the
          # batch. If it is not, do not return a batch for any of the submissions on that day.
          next unless submissions.any? && batch_enabled_for_daily_submission?(submissions.first.form_document)

          yielder << Batch.new(form_id, mode, submissions)
        end
      end
    end

    def weekly_batches(time_in_week)
      Enumerator.new do |yielder|
        form_ids_and_modes_with_send_weekly_submission_batch(time_in_week).each do |form_id, mode|
          submissions = Submission.for_form_and_mode(form_id, mode).in_week(time_in_week).order(created_at: :desc)

          # If the most recent submission is configured for weekly batching, include all submissions in that week in
          # the batch. If it is not, do not return a batch for any of the submissions in that week.
          next unless submissions.any? && batch_enabled_for_weekly_submission?(submissions.first.form_document)

          yielder << Batch.new(form_id, mode, submissions)
        end
      end
    end

  private

    def form_ids_and_modes_with_send_daily_submission_batch(date)
      # Get all form_ids and modes that have at least one submission on the date with daily batches enabled
      Submission.on_day(date)
                .where(DAILY_BATCH_FORM_DOCUMENT_CONDITION)
                .distinct
                .pluck(:form_id, :mode)
    end

    def form_ids_and_modes_with_send_weekly_submission_batch(begin_at)
      # Get all form_ids and modes that have at least one submission in the week with weekly batches enabled
      Submission.in_week(begin_at)
                .where(WEEKLY_BATCH_FORM_DOCUMENT_CONDITION)
                .distinct
                .pluck(:form_id, :mode)
    end

    def batch_enabled_for_daily_submission?(form_document)
      form_document["send_daily_submission_batch"] == true ||
        daily_delivery_configuration?(form_document)
    end

    def batch_enabled_for_weekly_submission?(form_document)
      form_document["send_weekly_submission_batch"] == true ||
        weekly_delivery_configuration?(form_document)
    end

    def daily_delivery_configuration?(form_document)
      form_document["delivery_configurations"]&.any? { |configuration| configuration["delivery_schedule"] == "daily" }
    end

    def weekly_delivery_configuration?(form_document)
      form_document["delivery_configurations"]&.any? { |configuration| configuration["delivery_schedule"] == "weekly" }
    end
  end
end
