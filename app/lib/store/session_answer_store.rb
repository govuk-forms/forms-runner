module Store
  class SessionAnswerStore
    include Store::Access

    ANSWERS_KEY = :answers
    LOCALES_KEY = :locales

    def initialize(store, form_id)
      @store = store
      @form_key = form_id.to_s
      @store[ANSWERS_KEY] ||= {}
      @store[LOCALES_KEY] ||= {}
    end

    def save_step(step, answer)
      @store[ANSWERS_KEY][@form_key] ||= {}
      @store[ANSWERS_KEY][@form_key][page_key(step)] = answer
    end

    def get_stored_answer(step)
      @store.dig(ANSWERS_KEY, @form_key, page_key(step))
    end

    def clear_stored_answer(step)
      @store.dig(ANSWERS_KEY, @form_key)&.delete(page_key(step))
    end

    def clear
      @store[ANSWERS_KEY][@form_key] = nil
      @store[LOCALES_KEY][@form_key] = nil
    end

    def form_submitted?
      @store[ANSWERS_KEY][@form_key].nil?
    end

    alias_method :starting_new_form?, :form_submitted?

    def answers
      @store[ANSWERS_KEY][@form_key]
    end

    def add_locale(locale)
      @store[LOCALES_KEY][@form_key] ||= []
      @store[LOCALES_KEY][@form_key] |= [locale.to_s]
    end

    def locales_used
      locales = @store.dig(LOCALES_KEY, @form_key) || []
      locales.map(&:to_sym) || []
    end
  end
end
