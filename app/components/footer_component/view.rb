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
        I18n.t("footer.accessibility_statement") => accessibility_statement,
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

    def accessibility_statement
      if @form&.has_custom_branding?
        form_branded_accessibility_statement_path(mode: @mode, form_id: @form.id, form_slug: @form.form_slug)
      else
        accessibility_statement_path(locale:)
      end
    end
  end
end
