class AwsSesDeliveryMethod
  attr_accessor :settings

  def initialize(settings)
    self.settings = settings
    @configuration_set_name = settings[:configuration_set_name] || Settings.aws.ses_submission_email_configuration_set_name
  end

  def deliver!(message)
    ses = Aws::SESV2::Client.new
    response = ses.send_email({
      content: {
        raw: {
          data: message.to_s,
        },
      },
      configuration_set_name: @configuration_set_name,
    })

    # Overwrite the generated message_id with the id returned by SES.
    message.message_id = response.message_id
  end
end
