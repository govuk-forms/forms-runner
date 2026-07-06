module FormHeaderComponent
  GOVUK_BASE_URL = "https://www.gov.uk/".freeze

  class View < ApplicationComponent
    def initialize(current_context:, mode:, hosting_environment: HostingEnvironment)
      @current_context = current_context
      @mode = mode
      @hosting_environment = hosting_environment
      super()
    end

    def call
      if @current_context.present?
        homepage_url = @mode.preview? ? Settings.forms_admin.base_url : GOVUK_BASE_URL

        safe_join([
          govuk_header(homepage_url:,
                       classes:) do |header|
            header.with_product_name(name: product_name_with_tag)
          end,
          govuk_service_navigation(
            service_name: form_name,
            service_url: form_start_page_url,
            navigation_items: navigation_items,
          ),
        ], "\n")
      else
        govuk_header(homepage_url: GOVUK_BASE_URL, classes:) do |header|
          header.with_product_name(name: product_name_with_tag)
        end
      end
    end

  private

    def product_name_with_tag
      govuk_tag(colour: colour_for_environment, text: environment_name).html_safe unless environment_name == I18n.t("environment_names.production")
    end

    def environment_name
      @hosting_environment.friendly_environment_name
    end

    def colour_for_environment
      case environment_name
      when "Local"
        "magenta"
      when "Development"
        "green"
      when "Staging"
        "yellow"
      else
        "blue"
      end
    end

    def classes
      ["govuk-header--full-width-border", "app-header", "app-header--#{@mode}"]
    end

    def form_name
      @current_context.form.name
    end

    def form_start_page_url
      form_path(mode: @mode.to_s, form_id: @current_context.form.id, form_slug: @current_context.form.form_slug)
    end

    def navigation_items
      return [] if @mode.live?

      [
        {
          text: I18n.t("preview_header.your_questions"),
          href: your_questions_url,
        },
      ]
    end

    def your_questions_url
      return "#{Settings.forms_admin.base_url}/forms/#{@current_context.form.id}/live/pages" if @mode.preview_live?

      "#{Settings.forms_admin.base_url}/forms/#{@current_context.form.id}/pages/"
    end
  end
end
