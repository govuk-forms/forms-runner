module FooterComponent
  class View < ApplicationComponent
    include Rails.application.routes.url_helpers

    def initialize(mode:, form:)
      @mode = mode
      @form = form
      super()
    end

    def meta_links
      links = {
        I18n.t("footer.accessibility_statement") => accessibility_statement_path(locale:),
        I18n.t("footer.cookies") => cookies_path(locale:),
      }

      if @form.present?
        links[I18n.t("footer.privacy_policy")] = form_privacy_path(
          mode: @mode, form_id: @form.id, form_slug: @form.form_slug,
        )
      end

      links
    end

  private

    def locale
      I18n.locale if I18n.locale != I18n.default_locale
    end
  end
end
