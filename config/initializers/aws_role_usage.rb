arn_matching_expr = /arn:aws:sts::498160065950:assumed-role\/[a-z0-9.]+-readonly\/\d+/

err_msg = <<~MSG
  You must have assumed the readonly role in the development account
  before assuming the forms-runner role in development account.

  gds aws forms-dev-readonly --shell
MSG

if Rails.env.development? && ENV["ASSUME_DEV_IAM_ROLE"]
  begin
    sts = Aws::STS::Client.new
    caller_ident = sts.get_caller_identity

    unless arn_matching_expr.match(caller_ident.arn)
      raise StandardError, err_msg
    end

    assumed_role = sts.assume_role({
      role_arn: "arn:aws:iam::498160065950:role/dev-forms-runner-ecs-task",
      role_session_name: "#{ENV['AWS_USER'].presence || ENV['USER']}-forms-runner-local",
    })

    ENV["AWS_ACCESS_KEY_ID"] = assumed_role.credentials.access_key_id
    ENV["AWS_SECRET_ACCESS_KEY"] = assumed_role.credentials.secret_access_key
    ENV["AWS_SESSION_TOKEN"] = assumed_role.credentials.session_token
    ENV["AWS_SESSION_EXPIRATION"] = assumed_role.credentials.expiration.iso8601
  rescue Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
    raise StandardError, err_msg
  end
end
