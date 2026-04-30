module Store
  class ReturnFromOneLoginStore
    class MissingReturnParamsError < StandardError
      def initialize(message = "Return from One Login parameters are missing from the session")
        super(message)
      end
    end

    RETURN_FROM_ONE_LOGIN_KEY = "return_from_one_login".freeze
    LAST_FORM_ID_KEY = "last_form_id".freeze
    LAST_FORM_SLUG_KEY = "last_form_slug".freeze
    LAST_MODE_KEY = "last_mode".freeze
    LAST_LOCALE_KEY = "last_locale".freeze

    def initialize(store)
      @store = store
    end

    def store_return_params(form:, mode:, locale:)
      @store[RETURN_FROM_ONE_LOGIN_KEY] ||= {}
      @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_FORM_ID_KEY] = form.id
      @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_FORM_SLUG_KEY] = form.form_slug
      @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_MODE_KEY] = mode.to_s
      @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_LOCALE_KEY] = locale
    end

    def form_path_params
      raise MissingReturnParamsError if @store[RETURN_FROM_ONE_LOGIN_KEY].blank?

      {
        mode: @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_MODE_KEY],
        form_id: @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_FORM_ID_KEY],
        form_slug: @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_FORM_SLUG_KEY],
        locale: @store[RETURN_FROM_ONE_LOGIN_KEY][LAST_LOCALE_KEY],
      }
    end

    def form_id
      raise MissingReturnParamsError if @store[RETURN_FROM_ONE_LOGIN_KEY].blank?

      @store.dig(RETURN_FROM_ONE_LOGIN_KEY, LAST_FORM_ID_KEY)
    end
  end
end
