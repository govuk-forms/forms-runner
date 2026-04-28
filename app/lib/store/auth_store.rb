module Store
  class AuthStore
    AUTH_KEY = "auth".freeze
    TOKEN_KEY = "token".freeze

    def initialize(store)
      @store = store
    end

    def store_token(token)
      @store[AUTH_KEY] = {
        TOKEN_KEY => token,
      }
    end

    def get_token
      @store.dig(AUTH_KEY, TOKEN_KEY)
    end

    def clear
      @store.delete(AUTH_KEY)
    end

    def logged_in?
      get_token.present?
    end
  end
end
