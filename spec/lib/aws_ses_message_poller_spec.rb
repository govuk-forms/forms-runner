require "rails_helper"

RSpec.describe AwsSesMessagePoller do
  subject(:poller) do
    described_class.new(
      queue_name: queue_name,
      job_class_name: job_class_name,
      job_id: job_id,
    )
  end

  let(:queue_name) { "test_queue" }
  let(:job_class_name) { "TestJob" }
  let(:job_id) { "test-job-id" }
  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:sts_client) { instance_double(Aws::STS::Client) }
  let(:account_id) { "123456789012" }
  let(:queue_url) { "https://sqs.eu-west-2.amazonaws.com/#{account_id}/#{queue_name}" }

  let(:sqs_message_id) { "sqs-message-id" }
  let(:receipt_handle) { "receipt-handle" }
  let(:sns_message_timestamp) { "2025-05-09T10:25:43.972Z" }
  let(:message_id) { "mail-message-id" }

  let(:sns_message_body) do
    {
      "Message" => ses_message_body.to_json,
      "Timestamp" => sns_message_timestamp,
    }.to_json
  end

  let(:ses_message_body) do
    {
      "mail" => { "messageId" => message_id },
      "eventType" => "TestEvent",
    }
  end

  let(:sqs_message) do
    instance_double(
      Aws::SQS::Types::Message,
      message_id: sqs_message_id,
      receipt_handle: receipt_handle,
      body: sns_message_body,
    )
  end

  before do
    allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
    allow(sts_client).to receive(:get_caller_identity).and_return(OpenStruct.new(account: account_id))
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
  end

  describe "#poll", :capture_logging do
    context "when no block is provided" do
      it "raises an ArgumentError" do
        expect { poller.poll }.to raise_error(ArgumentError, "Block required for message processing")
      end
    end

    context "when there are messages in the queue" do
      before do
        allow(sqs_client).to receive(:receive_message).and_return(
          OpenStruct.new(messages: [sqs_message]),
          OpenStruct.new(messages: []),
        )
        allow(sqs_client).to receive(:delete_message)
      end

      it "processes messages using the provided block" do
        block_called = false
        received_ses_message_id = nil
        received_ses_message = nil

        poller.poll do |ses_message_id, ses_message|
          block_called = true
          received_ses_message_id = ses_message_id
          received_ses_message = ses_message
        end

        expect(block_called).to be true
        expect(received_ses_message_id).to eq message_id
        expect(received_ses_message).to eq ses_message_body
      end

      it "sets logging attributes for the message" do
        poller.poll { |_submission, _ses_message| }

        info_log = log_lines.find { |line| line["level"] == "INFO" }

        expect(info_log).to include(
          "message" => "Received 1 messages - #{job_class_name}",
        )
      end

      it "deletes the message after successful processing" do
        poller.poll { |_ses_message_id, _ses_message| }

        expect(sqs_client).to have_received(:delete_message).with(
          queue_url: queue_url,
          receipt_handle: receipt_handle,
        )
      end

      it "resets logging attributes after processing" do
        poller.poll { |_ses_message_id, _ses_message| }

        expect(CurrentJobLoggingAttributes.sqs_message_id).to be_nil
        expect(CurrentJobLoggingAttributes.sns_message_timestamp).to be_nil
        expect(CurrentJobLoggingAttributes.delivery_reference).to be_nil
      end
    end

    context "when processing multiple messages" do
      let(:messages) { Array.new(5, sqs_message) }

      before do
        allow(sqs_client).to receive(:receive_message).and_return(
          OpenStruct.new(messages: messages),
          OpenStruct.new(messages: []),
        )
        allow(sqs_client).to receive(:delete_message)
      end

      it "processes all messages" do
        call_count = 0
        poller.poll { |_ses_message_id, _ses_message| call_count += 1 }

        expect(call_count).to eq 5
      end

      it "deletes all messages" do
        poller.poll { |_ses_message_id, _ses_message| }

        expect(sqs_client).to have_received(:delete_message).exactly(5).times
      end
    end

    context "when an error occurs during processing" do
      before do
        allow(sqs_client).to receive(:receive_message).and_return(
          OpenStruct.new(messages: [sqs_message, sqs_message]),
          OpenStruct.new(messages: []),
        )
        allow(sqs_client).to receive(:delete_message)
        allow(Sentry).to receive(:capture_exception)
      end

      it "logs a warning" do
        call_count = 0
        poller.poll do |_ses_message_id, _ses_message|
          call_count += 1
          raise StandardError, "Test error" if call_count == 1
        end

        warn_log = log_lines.find { |line| line["level"] == "WARN" }

        expect(warn_log).to include(
          "message" => "Error processing message - StandardError: Test error",
        )
      end

      it "sends the error to Sentry" do
        call_count = 0
        poller.poll do |_ses_message_id, _ses_message|
          call_count += 1
          raise StandardError, "Test error" if call_count == 1
        end

        expect(Sentry).to have_received(:capture_exception)
      end

      it "does not delete the message when an error occurs" do
        poller.poll { |_ses_message_id, _ses_message| raise StandardError, "Test error" }

        expect(sqs_client).not_to have_received(:delete_message)
      end

      it "continues processing subsequent messages" do
        call_count = 0
        poller.poll do |_ses_message_id, _ses_message|
          call_count += 1
          raise StandardError, "Test error" if call_count == 1
        end

        expect(call_count).to eq 2
      end

      it "resets logging attributes even after an error" do
        poller.poll { |_ses_message_id, _ses_message| raise StandardError, "Test error" }

        expect(CurrentJobLoggingAttributes.sqs_message_id).to be_nil
        expect(CurrentJobLoggingAttributes.sns_message_timestamp).to be_nil
        expect(CurrentJobLoggingAttributes.delivery_reference).to be_nil
      end
    end

    context "when the queue is empty" do
      before do
        allow(sqs_client).to receive(:receive_message).and_return(
          OpenStruct.new(messages: []),
        )
      end

      it "exits the polling loop immediately" do
        block_called = false
        poller.poll { |_ses_message_id, _ses_message| block_called = true }

        expect(block_called).to be false
      end
    end
  end
end
