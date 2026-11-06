class CurrentJobLoggingAttributes < ActiveSupport::CurrentAttributes
  attribute :job_class,
            :job_id,
            :form_id,
            :form_name,
            :form_version,
            :submission_reference,
            :submission_uuid,
            :preview,
            :delivery_id,
            :delivery_reference,
            :delivery_schedule,
            :delivery_method,
            :delivery_formats,
            :batch_begin_at,
            :email_id,
            :sqs_message_id,
            :sns_message_timestamp

  def as_hash
    {
      job_class:,
      job_id:,
      form_id:,
      form_name:,
      form_version:,
      submission_reference:,
      submission_uuid:,
      preview: preview&.to_s,
      delivery_id:,
      delivery_reference:,
      delivery_schedule:,
      delivery_method:,
      delivery_formats:,
      batch_begin_at:,
      email_id:,
      sqs_message_id:,
      sns_message_timestamp:,
    }.compact
  end
end
