module Store
  class AuthStore
    AUTH_KEY = "auth".freeze
    TOKEN_KEY = "token".freeze
    SUB_KEY = "sub".freeze
    EMAIL_KEY = "email".freeze
    AUTHENTICATED_AT_KEY = "authenticated_at".freeze

    def initialize(store)
      @store = store
    end

    def store_session(sub:, email:, token:, authenticated_at:)
      @store[AUTH_KEY] = {
        SUB_KEY => sub,
        EMAIL_KEY => email,
        TOKEN_KEY => token,
        AUTHENTICATED_AT_KEY => authenticated_at,
      }
    end

    def get_token
      @store.dig(AUTH_KEY, TOKEN_KEY)
    end

    def clear
      @store.delete(AUTH_KEY)
    end

    def sub
      @store.dig(AUTH_KEY, SUB_KEY) unless expired?
    end

    def email
      @store.dig(AUTH_KEY, EMAIL_KEY) unless expired?
    end

    def authenticated_at
      @store.dig(AUTH_KEY, AUTHENTICATED_AT_KEY)
    end

    def logged_in?
      get_token.present? && !expired?
    end

  private

    def expired?
      authenticated_at.blank? || Time.current.to_i - authenticated_at >= Settings.govuk_one_login.session_timeout_seconds
    end
  end
end
