class CurrentJobLoggingAttributes < ActiveSupport::CurrentAttributes
  attribute :job_class,
            :job_id,
            :form_id,
            :form_name,
            :submission_reference,
            :preview,
            :delivery_id,
            :delivery_reference,
            :delivery_schedule,
            :batch_begin_at,
            :confirmation_email_id,
            :sqs_message_id,
            :sns_message_timestamp

  def as_hash
    {
      job_class:,
      job_id:,
      form_id:,
      form_name:,
      submission_reference:,
      preview: preview.to_s,
      delivery_id:,
      delivery_reference:,
      delivery_schedule:,
      batch_begin_at:,
      confirmation_email_id:,
      sqs_message_id:,
      sns_message_timestamp:,
    }.compact_blank
  end
end
