require "rails_helper"

RSpec.describe CurrentJobLoggingAttributes do
  subject(:current) { described_class.new }

  describe "#as_hash" do
    it "includes only properties that are set" do
      current.job_class = "AClass"
      expect(current.as_hash).to eq({ job_class: "AClass" })
    end

    it "includes all properties when they are set" do
      current.job_class = "AClass"
      current.job_id = "xyz789"
      current.form_id = 456
      current.form_name = "A form"
      current.submission_reference = "ABC123"
      current.preview = true
      current.delivery_id = 123
      current.delivery_reference = "REF123"
      current.delivery_schedule = "immediate"
      current.delivery_method = "email"
      current.delivery_formats = %w[csv json]
      current.batch_begin_at = Time.zone.parse("2026-01-01 12:00")
      current.confirmation_email_id = "CONF123"
      current.sqs_message_id = "SQS123"
      current.sns_message_timestamp = "2025-05-09T10:25:43.972Z"

      expect(current.as_hash).to eq({
        job_class: "AClass",
        job_id: "xyz789",
        form_id: 456,
        form_name: "A form",
        submission_reference: "ABC123",
        preview: "true",
        delivery_id: 123,
        delivery_reference: "REF123",
        delivery_schedule: "immediate",
        delivery_method: "email",
        delivery_formats: %w[csv json],
        batch_begin_at: Time.zone.parse("2026-01-01 12:00"),
        confirmation_email_id: "CONF123",
        sqs_message_id: "SQS123",
        sns_message_timestamp: "2025-05-09T10:25:43.972Z",
      })
    end

    it "includes the delivery_formats when set to an empty array (this is used by Splunk reports)" do
      current.delivery_formats = []

      expect(current.as_hash).to eq({ delivery_formats: [] })
    end
  end
end
