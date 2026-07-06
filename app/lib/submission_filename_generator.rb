module SubmissionFilenameGenerator
  class << self
    MAX_LENGTH = 100
    PREFIX = "govuk_forms_".freeze
    CSV_EXTENSION = ".csv".freeze
    JSON_EXTENSION = ".json".freeze
    DATE_FORMAT = "%Y-%m-%d".freeze

    def csv_filename(form_name:, submission_reference:)
      filename(form_name:, submission_reference:, extension: CSV_EXTENSION)
    end

    def json_filename(form_name:, submission_reference:)
      filename(form_name:, submission_reference:, extension: JSON_EXTENSION)
    end

    def filename(form_name:, submission_reference:, extension:)
      reference_part = "_#{submission_reference}"

      name_part_max_length = MAX_LENGTH - extension.length - PREFIX.length - reference_part.length
      name_part = name_part(form_name, name_part_max_length)

      "#{PREFIX}#{name_part}#{reference_part}#{extension}"
    end

    def daily_batch_csv_filename(form_name:, mode:, csv_version:, date:)
      date_part = "_#{date.strftime(DATE_FORMAT)}"
      batch_csv_filename(form_name:, mode:, csv_version:, date_part:)
    end

    def weekly_batch_csv_filename(form_name:, mode:, csv_version:, begin_date:, end_date:)
      date_part = "_#{begin_date.strftime(DATE_FORMAT)}--#{end_date.strftime(DATE_FORMAT)}"
      batch_csv_filename(form_name:, mode:, csv_version:, date_part:)
    end

  private

    def name_part(form_name, name_part_max_length)
      form_name
        .parameterize(separator: "_")
        .truncate(name_part_max_length, separator: "_", omission: "")
    end

    def batch_csv_filename(form_name:, mode:, csv_version:, date_part:)
      mode_prefix = mode.preview? ? "test_" : ""
      version_part = csv_version.presence ? "_#{csv_version}" : ""

      name_part_max_length = MAX_LENGTH - CSV_EXTENSION.length - mode_prefix.length - PREFIX.length - date_part.length - version_part.length
      name_part = name_part(form_name, name_part_max_length)

      "#{mode_prefix}#{PREFIX}#{name_part}#{date_part}#{version_part}#{CSV_EXTENSION}"
    end
  end
end
