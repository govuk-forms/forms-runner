require "csv"

class CsvGenerator
  class << self
    def generate_submission(submission:, is_s3_submission:)
      CSV.generate do |csv|
        csv << headers(submission, is_s3_submission)
        csv << values_for_submission(submission, is_s3_submission)
      end
    end

    def generate_batched_submissions(submissions_query:, is_s3_submission:)
      sorted_submissions = submissions_query.ordered_by_form_version_and_date

      rows_by_version = []

      sorted_submissions.each do |submission|
        current_headers = rows_by_version.last&.first
        unless current_headers == headers(submission, is_s3_submission)
          # Start a new CSV if the headers are different to the previous submission
          rows_by_version << [headers(submission, is_s3_submission)]
        end
        rows_by_version.last << values_for_submission(submission, is_s3_submission)
      end

      rows_by_version.map do |rows|
        CSV.generate { |csv| rows.each { |line| csv << line } }
      end
    end

  private

    def headers(submission, is_s3_submission)
      headers = [I18n.t("submission_csv.reference"), I18n.t("submission_csv.submitted_at")]

      submission.journey.all_steps.each do |step|
        headers.push(*step.show_answer_in_csv(submission_reference: submission.reference, is_s3_submission:).keys)
      end

      if submission.form.multilingual?
        headers.push(I18n.t("submission_csv.language"))
      end

      headers
    end

    def values_for_submission(submission, is_s3_submission)
      values = [submission.reference, submission.submission_time.iso8601]

      submission.journey.all_steps.each do |step|
        answer_parts = step.show_answer_in_csv(submission_reference: submission.reference, is_s3_submission:)
        values.push(*answer_parts.values)
      end

      if submission.form.multilingual?
        values.push(submission.submission_locale)
      end

      csv_safe_values(values)
    end

    def csv_safe_values(values)
      # this sanitizes values commonly used in CSV injection attacks by prepending a single quote
      sanitized_values = []
      values.map do |value|
        sanitized_values.push(value.match?(/\A[=+\-@\t\r]/) ? "0x09#{value}" : value)
      end
      sanitized_values
    end
  end
end
