require "rails_helper"

RSpec.describe AuthService do
  subject(:auth_service) { described_class.new }

  let(:end_session_endpoint) { "http://example.com/one-login-mock/logout" }

  before do
    idp_configuration = instance_double(OmniAuth::GovukOneLogin::IdpConfiguration, end_session_endpoint:)
    allow(Rails.application.config.x).to receive(:one_login).and_return(double(idp_configuration:))
  end

  describe "#logout_request" do
    let(:token) { Faker::Alphanumeric.alphanumeric }
    let(:post_logout_redirect_uri) { "https://example.com/some-path?with=params" }

    it "returns a logout request with the expected One Login URI" do
      logout_request = auth_service.logout_request(token, post_logout_redirect_uri)
      expect(logout_request.redirect_uri).to start_with(end_session_endpoint)
    end

    it "strips query params from the post_logout_redirect_uri" do
      logout_request = auth_service.logout_request(token, post_logout_redirect_uri)
      redirect_uri = URI.parse(logout_request.redirect_uri)
      query = Rack::Utils.parse_query(redirect_uri.query)
      expect(query).to include("post_logout_redirect_uri" => "https://example.com/some-path",
                               "id_token_hint" => token)
    end
  end
end
