require "rails_helper"

RSpec.describe Store::AuthStore do
  subject(:auth_store) { described_class.new(store) }

  let(:store) { {} }
  let(:sub) { Faker::Alphanumeric.alphanumeric }
  let(:email) { Faker::Internet.email }
  let(:token) { Faker::Alphanumeric.alphanumeric }
  let(:authenticated_at) { Time.current.to_i }

  describe "#store_session" do
    it "stores the sub, email, token and authenticated_at" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      expect(auth_store.sub).to eq(sub)
      expect(auth_store.email).to eq(email)
      expect(auth_store.get_token).to eq(token)
      expect(auth_store.authenticated_at).to eq(authenticated_at)
    end
  end

  describe "#clear" do
    it "removes the stored session" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      auth_store.clear

      expect(auth_store.get_token).to be_nil
    end
  end

  describe "#get_token" do
    it "returns the token" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      expect(auth_store.get_token).to eq(token)
    end
  end

  describe "#sub" do
    it "returns the sub when the session has not expired" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      expect(auth_store.sub).to eq(sub)
    end

    it "returns nil when the session has expired" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      travel 1.hour + 1.second

      expect(auth_store.sub).to be_nil
    end
  end

  describe "#email" do
    it "returns the email when the session has not expired" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      expect(auth_store.email).to eq(email)
    end

    it "returns nil when the session has expired" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      travel 1.hour + 1.second

      expect(auth_store.email).to be_nil
    end
  end

  describe "#logged_in?" do
    it "returns true when the token is present and authenticated_at is within the last hour" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      expect(auth_store.logged_in?).to be true
    end

    it "returns false when no session is stored" do
      expect(auth_store.logged_in?).to be false
    end

    it "returns false when authenticated_at is missing" do
      auth_store.store_session(sub:, email:, token:, authenticated_at: nil)

      expect(auth_store.logged_in?).to be false
    end

    it "returns true when authenticated_at was just under an hour ago" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      travel 59.minutes

      expect(auth_store.logged_in?).to be true
    end

    it "returns false when authenticated_at was exactly an hour ago" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      travel 1.hour

      expect(auth_store.logged_in?).to be false
    end

    it "returns false when authenticated_at was more than an hour ago" do
      auth_store.store_session(sub:, email:, token:, authenticated_at:)

      travel 1.hour + 1.second

      expect(auth_store.logged_in?).to be false
    end
  end
end
