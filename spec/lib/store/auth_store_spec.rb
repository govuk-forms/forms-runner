require "rails_helper"

RSpec.describe Store::AuthStore do
  subject(:auth_store) { described_class.new(store) }

  let(:store) { {} }
  let(:token) { Faker::Alphanumeric.alphanumeric }

  it "stores and returns the auth token" do
    auth_store.store_token(token)

    expect(auth_store.get_token).to eq(token)
  end

  describe "#logged_in" do
    it "returns true when the auth token is stored" do
      auth_store.store_token(token)

      expect(auth_store.logged_in?).to be true
    end

    it "returns false when the auth token is not stored" do
      expect(auth_store.logged_in?).to be false
    end
  end
end
