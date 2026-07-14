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

    def custom_branding_style
      return unless custom_branding?

      branding = @form.branding

      content_tag(:style) do
        ":root {
          --custom-footer-border-colour: #{branding['border_colour']};
          --govuk-template-background-colour: #f3f3f3;
        }".html_safe
      end
    end

  private

    def locale
      I18n.locale if I18n.locale != I18n.default_locale
    end

    def custom_branding?
      return false if @form.blank?

      @form.has_custom_branding?
    end
  end
end
