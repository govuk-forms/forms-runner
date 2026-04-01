class CurrentRequestLoggingAttributes < ActiveSupport::CurrentAttributes
  attribute :request_host,
            :request_id,
            :form_id,
            :form_name,
            :preview,
            :page_id,
            :step_slug,
            :answer_type,
            :session_id_hash,
            :trace_id,
            :question_number,
            :submission_reference,
            :confirmation_email_reference,
            :rescued_exception,
            :rescued_exception_trace,
            :validation_errors,
            :answer_metadata

  def as_hash
    {
      request_host:,
      request_id:,
      form_id:,
      form_name:,
      preview: preview.to_s,
      page_id:,
      step_slug:,
      answer_type:,
      session_id_hash:,
      trace_id:,
      question_number:,
      submission_reference:,
      confirmation_email_reference:,
      rescued_exception:,
      rescued_exception_trace:,
      validation_errors:,
      answer_metadata:,
    }.compact_blank
  end
end
