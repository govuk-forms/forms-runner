# frozen_string_literal: true

module CustomBrandingComponent
  class View < ApplicationComponent
    def initialize(form: nil)
      super()
      @form = form
    end

    def render?
      @form.present? && @form.has_custom_branding?
    end

    delegate :branding, to: :@form
  end
end
