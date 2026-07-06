class AwsSesMessagePoller
  # Class is used to poll SQS queues which recieves either SES bounce, complaint, or delivery notifications.
  # https://docs.aws.amazon.com/ses/latest/dg/notification-contents.html
  require "aws-sdk-sqs"
  require "aws-sdk-sts"

  REGION = "eu-west-2".freeze
  MAX_NUMBER_OF_MESSAGES = 10
  POLLING_PERIOD = 20

  def initialize(queue_name:, job_class_name:, job_id:)
    @queue_name = queue_name
    @job_class_name = job_class_name
    @job_id = job_id
  end

  def poll(&block)
    raise ArgumentError, "Block required for message processing" unless block_given?

    sts_client = Aws::STS::Client.new(region: REGION)
    queue_url = "https://sqs.#{REGION}.amazonaws.com/#{sts_client.get_caller_identity.account}/#{@queue_name}"
    sqs_client = Aws::SQS::Client.new(region: REGION)

    loop do
      messages = receive_messages(sqs_client, queue_url)

      break if messages.empty?

      process_messages(sqs_client, queue_url, messages, &block)
    end
  end

private

  def receive_messages(sqs_client, queue_url)
    response = sqs_client.receive_message(
      queue_url: queue_url,
      max_number_of_messages: MAX_NUMBER_OF_MESSAGES,
      wait_time_seconds: POLLING_PERIOD, # Any value > 0 enables long polling
    )

    Rails.logger.info("Received #{response.messages.length} messages - #{@job_class_name}")

    response.messages
  end

  def process_messages(sqs_client, queue_url, messages, &block)
    messages.each do |message|
      sqs_message_id = message.message_id
      CurrentJobLoggingAttributes.sqs_message_id = sqs_message_id

      receipt_handle = message.receipt_handle
      sns_message = JSON.parse(message.body)
      CurrentJobLoggingAttributes.sns_message_timestamp = sns_message["Timestamp"]

      ses_message = JSON.parse(sns_message["Message"])
      ses_message_id = ses_message["mail"]["messageId"]

      # Call the provided block with the SES message ID and contents
      block.call(ses_message_id, ses_message)

      sqs_client.delete_message(queue_url: queue_url, receipt_handle: receipt_handle)
    rescue StandardError => e
      Rails.logger.warn("Error processing message - #{e.class.name}: #{e.message}")
      Sentry.capture_exception(e)
    ensure
      CurrentJobLoggingAttributes.reset
    end
  end
end
