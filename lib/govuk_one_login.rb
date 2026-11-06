module GovukOneLogin
  class << self
    def domain
      @domain ||= Settings.govuk_one_login.domain || "account.gov.uk"
    end

    def idp_base_url
      "https://oidc.#{domain}/"
    end

    def home_url
      "https://home.#{domain}"
    end

    def signed_out_url
      "#{home_url}/signed-out"
    end
  end
end
