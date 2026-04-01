namespace :submissions do
  desc "Check delivery statuses"
  task check_delivery_statuses: :environment do
    Rails.logger.info "#{Delivery.pending.count} pending deliveries"
    Rails.logger.info "#{Delivery.failed.count} failed deliveries"
  end

  desc "List all bounced submission deliveries for the given form ID"
  task :list_bounced_submissions_for_form, %i[form_id] => :environment do |_t, args|
    form_id = args[:form_id]

    usage_message = "usage: rake submissions:list_bounced_submissions_for_form[<form_id>]".freeze
    abort usage_message if form_id.blank?

    deliveries = Delivery.failed.joins(:submissions).where(submissions: { form_id: form_id }).distinct
    Rails.logger.info "Found #{deliveries.length} bounced submission deliveries for form with ID #{form_id}"
    deliveries.immediate.each do |delivery|
      submission = delivery.submissions.first
      Rails.logger.info "Immediate delivery - submission reference: #{submission.reference}, created_at: #{submission.created_at}, last_attempt_at: #{delivery.last_attempt_at}"
    end
    deliveries.daily.each do |delivery|
      Rails.logger.info "Daily batch delivery - delivery_reference: #{delivery.delivery_reference}, created_at: #{delivery.created_at}, last_attempt_at: #{delivery.last_attempt_at}"
    end
    deliveries.weekly.each do |delivery|
      Rails.logger.info "Weekly batch delivery - delivery_reference: #{delivery.delivery_reference}, created_at: #{delivery.created_at}, last_attempt_at: #{delivery.last_attempt_at}"
    end
  end

  # Print attributes for a submission
  #
  # Given just a submission reference, it prints the whole submission record, with the answers filtered out.
  # If you need to see the actual answer data, provide one or more step_slugs as well.
  #
  # Example:
  #
  #   submissions:inspect_submission_data[S37296TN]
  #   submissions:inspect_submission_data[S37296TN,Y5YQWF2w,SfPkwVkM]
  #
  desc "Fetch and display data for a specific submission given a reference"
  task :inspect_submission_data, [:reference] => :environment do |_t, args|
    reference, *step_slugs = args.to_a

    submission = Submission.find_by(reference: reference)
    abort "Submission with reference #{reference} not found" if submission.nil?

    if step_slugs.empty?
      puts "Data for submission with reference #{reference}:"
      pp submission
    else
      step_slugs.each do |slug|
        question_text = submission.form.steps.find { it.id == slug }&.data&.question_text
        puts "Answer(s) to #{slug} (#{question_text}) for submission with reference #{reference}"
        pp submission.answers.slice(slug)
      end
    end
  end

  desc "Retry bounced deliveries"
  task :retry_bounced_deliveries, %i[form_id] => :environment do |_, args|
    form_id = args[:form_id]

    usage_message = "usage: rake submissions:retry_bounced_deliveries[<form_id>]".freeze
    abort usage_message if form_id.blank?

    bounced_deliveries = Delivery.failed.joins(:submissions).where(submissions: { form_id: form_id }).distinct

    Rails.logger.info "#{bounced_deliveries.length} deliveries to retry for form with ID: #{form_id}"

    bounced_deliveries.each do |delivery|
      submission = delivery.submissions.first
      if delivery.immediate?
        Rails.logger.info "Retrying submission with reference #{submission.reference} for form with ID: #{form_id}"
        SendSubmissionJob.perform_later(submission)
      elsif delivery.daily?
        Rails.logger.info "Retrying daily batch delivery with delivery_id: #{delivery.id} for date: #{delivery.batch_begin_at.to_date} for form with ID: #{form_id}"
        SendSubmissionBatchJob.perform_later(delivery:)
      elsif delivery.weekly?
        Rails.logger.info "Retrying weekly batch delivery with delivery_id: #{delivery.id} for week starting: #{delivery.batch_begin_at.to_date} for form with ID: #{form_id}"
        SendSubmissionBatchJob.perform_later(delivery:)
      end
    end
  end

  desc "Disregard bounced delivery"
  task :disregard_bounced_delivery, %i[delivery_reference] => :environment do |_, args|
    delivery_reference = args[:delivery_reference]

    usage_message = "usage: rake submissions:disregard_bounced_delivery[<delivery_reference>]".freeze
    abort usage_message if delivery_reference.blank?

    delivery = Delivery.find_by(delivery_reference: delivery_reference)

    if delivery.blank?
      Rails.logger.info "No delivery found with delivery_reference #{delivery_reference}"
      next
    end

    unless delivery.failed?
      Rails.logger.info "Delivery with delivery_reference #{delivery_reference} hasn't bounced"
      next
    end

    delivery.update!(failed_at: nil, failure_reason: nil)
    Rails.logger.info "Disregarded bounce of delivery with delivery_reference #{delivery_reference}"
  end

  desc "Disregard bounced deliveries created between two timestamps for a specific form"
  task :disregard_bounced_deliveries_for_form, %i[form_id start_timestamp end_timestamp dry_run] => :environment do |_, args|
    form_id = args[:form_id]
    start_timestamp = args[:start_timestamp]
    end_timestamp = args[:end_timestamp]
    dry_run_arg = args[:dry_run]
    dry_run = dry_run_arg == "true"

    usage_message = "usage: rake submissions:disregard_bounced_deliveries_for_form[<form_id>, <start_timestamp>, <end_timestamp>, <dry_run>]".freeze
    if form_id.blank? || start_timestamp.blank? || end_timestamp.blank? || !dry_run_arg.in?(%w[true false])
      abort usage_message
    end

    start_time = Time.zone.parse(start_timestamp)
    end_time = Time.zone.parse(end_timestamp)

    if start_time.nil? || end_time.nil?
      abort "Error: Invalid timestamp format. Use ISO 8601 format (e.g. '2024-01-01T00:00:00Z')"
    end

    if start_time >= end_time
      abort "Error: Start timestamp must be before end timestamp"
    end

    Rails.logger.info "Dry run mode: #{dry_run ? 'enabled' : 'disabled'}"

    deliveries = Delivery.failed
                         .joins(:submissions)
                         .where(submissions: { form_id: form_id })
                         .where(created_at: start_time..end_time)
                         .distinct

    Rails.logger.info "Found #{deliveries.length} bounced submission deliveries to disregard for form ID #{form_id} in time range: #{start_time} to #{end_time}"

    deliveries.each do |delivery|
      if dry_run
        Rails.logger.info "Would disregard bounce of delivery with delivery_reference #{delivery.delivery_reference} which was created at #{delivery.created_at}"
      else
        delivery.update!(failed_at: nil, failure_reason: nil)
        Rails.logger.info "Disregarded bounce of delivery with delivery_reference #{delivery.delivery_reference}"
      end
    end
  end

  desc "Re-deliver submissions created between two timestamps for a specific form"
  task :redeliver_submissions_by_date, %i[form_id start_timestamp end_timestamp dry_run] => :environment do |_, args|
    form_id = args[:form_id]
    start_timestamp = args[:start_timestamp]
    end_timestamp = args[:end_timestamp]
    dry_run_arg = args[:dry_run]
    dry_run = dry_run_arg == "true"

    usage_message = "usage: rake submissions:redeliver_submissions_by_date[<form_id>,<start_timestamp>,<end_timestamp>,<dry_run>]".freeze

    if form_id.blank? || start_timestamp.blank? || end_timestamp.blank? || !dry_run_arg.in?(%w[true false])
      abort usage_message
    end

    start_time = Time.zone.parse(start_timestamp)
    end_time = Time.zone.parse(end_timestamp)

    if start_time.nil? || end_time.nil?
      abort "Error: Invalid timestamp format. Use ISO 8601 format (e.g. '2024-01-01T00:00:00Z')"
    end

    if start_time >= end_time
      abort "Error: Start timestamp must be before end timestamp"
    end

    submissions_to_redeliver = Submission.where(form_id: form_id)
                                         .where(created_at: start_time..end_time)

    Rails.logger.info "Time range: #{start_time} to #{end_time}"
    Rails.logger.info "Dry run mode: #{dry_run ? 'enabled' : 'disabled'}"

    if submissions_to_redeliver.any?
      Rails.logger.info "Found #{submissions_to_redeliver.count} submissions to re-deliver for form ID: #{form_id}"

      submissions_to_redeliver.each do |submission|
        if dry_run
          Rails.logger.info "Would re-deliver submission with reference #{submission.reference}"
        else
          Rails.logger.info "Re-delivering submission with reference #{submission.reference}"
          SendSubmissionJob.perform_later(submission)
        end
      end
    else
      Rails.logger.info "No submissions found matching the criteria"
    end
  end

  desc "Re-deliver submission batch deliveries created between two timestamps for a specific form"
  task :redeliver_batches_by_date, %i[form_id start_timestamp end_timestamp dry_run] => :environment do |_, args|
    form_id = args[:form_id]
    start_timestamp = args[:start_timestamp]
    end_timestamp = args[:end_timestamp]
    dry_run_arg = args[:dry_run]
    dry_run = dry_run_arg == "true"

    usage_message = "usage: rake submissions:redeliver_batches_by_date[<form_id>,<start_timestamp>,<end_timestamp>,<dry_run>]".freeze

    if form_id.blank? || start_timestamp.blank? || end_timestamp.blank? || !dry_run_arg.in?(%w[true false])
      abort usage_message
    end

    start_time = Time.zone.parse(start_timestamp)
    end_time = Time.zone.parse(end_timestamp)

    if start_time.nil? || end_time.nil?
      abort "Error: Invalid timestamp format. Use ISO 8601 format (e.g. '2024-01-01T00:00:00Z')"
    end

    if start_time >= end_time
      abort "Error: Start timestamp must be before end timestamp"
    end

    deliveries_to_redeliver = Delivery.joins(:submissions)
                                      .where(submissions: { form_id: form_id })
                                      .where.not(delivery_schedule: "immediate")
                                      .where(created_at: start_time..end_time)
                                      .distinct

    Rails.logger.info "Time range: #{start_time} to #{end_time}"
    Rails.logger.info "Dry run mode: #{dry_run ? 'enabled' : 'disabled'}"

    if deliveries_to_redeliver.any?
      Rails.logger.info "Found #{deliveries_to_redeliver.count} submission batches to re-deliver for form ID: #{form_id}"

      deliveries_to_redeliver.each do |delivery|
        if dry_run
          Rails.logger.info "Would re-deliver batch with ID #{delivery.id} and delivery reference #{delivery.delivery_reference}"
        else
          Rails.logger.info "Re-delivering batch ID #{delivery.id} and delivery reference #{delivery.delivery_reference}"
          SendSubmissionBatchJob.perform_later(delivery:)
        end
      end
    else
      Rails.logger.info "No batches found matching the criteria"
    end
  end

  namespace :file_answers do
    desc "Generate filename for file upload answers that do not have an original filename stored and schedule the submission to be sent"
    task :fix_missing_original_filenames, %i[reference] => :environment do |_, args|
      submission = Submission.find_by(reference: args.reference)
      abort "No submission found with reference #{args.reference}" if submission.blank?

      submission.answers.each_pair do |question_id, answer|
        next unless answer.include?("original_filename") && answer["original_filename"].blank? && answer["uploaded_file_key"].present?

        question = submission.form.page_by_id(question_id)
        extension = ::File.extname(answer["uploaded_file_key"])
        filename = "#{question.position}-#{question.question_text.parameterize}#{extension}"
        answer["original_filename"] = filename
      end

      submission.save!

      if submission.answers_previously_changed?
        Rails.logger.info "Re-delivering submission with reference #{submission.reference}"
        SendSubmissionJob.perform_later(submission)
      end
    end
  end
end
