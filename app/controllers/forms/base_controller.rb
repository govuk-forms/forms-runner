module Forms
  class BaseController < ApplicationController
    prepend_before_action :set_form
    around_action :set_locale

    def redirect_to_friendly_url_start
      redirect_to form_step_path(params.require(:form_id), @form.form_slug, @form.start_page)
      LogEventService.log_form_start unless mode.preview?
    end

    rescue_from ActiveResource::ResourceNotFound, RepeatableStep::AnswerIndexError do
      I18n.with_locale(locale) do
        render template: "errors/not_found", status: :not_found
      end
    end

    def error_repeat_submission
      @current_context = Flow::Context.new(form: @form, store: session)
      render template: "errors/repeat_submission", locals: { form: @form }
    end

    def set_request_logging_attributes
      super
      CurrentRequestLoggingAttributes.form_name = @form.name
      CurrentRequestLoggingAttributes.preview = mode.preview?
    end

  private

    def current_context
      @current_context ||= Flow::Context.new(form: @form, store: session)
    end

    def mode
      @mode ||= Mode.new(params[:mode])
    end

    def default_url_options
      { mode:, locale: locale_param }
    end

    def set_available_languages
      @available_languages = current_context.form.available_languages if current_context.form.multilingual?
    end

    def set_form
      form_document = Api::V2::FormDocumentRepository.find_with_mode(form_id:, mode:, language: locale)

      return handle_form_not_found if form_document.blank?

      @form = Form.new(form_document)
      raise ActiveResource::ResourceNotFound, "Form has no steps" unless @form.start_page
    end

    def handle_form_not_found
      I18n.with_locale(locale) do
        if locale == "cy"
          archived_welsh_form_document = Api::V2::FormDocumentRepository.find(form_id:, tag: :archived, language: :cy)
          live_english_form_document = Api::V2::FormDocumentRepository.find(form_id:, tag: :live, language: :en)

          if archived_welsh_form_document.present? && live_english_form_document.present?
            return render template: "forms/archived_welsh/show",
                          locals: { form: Form.new(live_english_form_document) },
                          status: :not_found
          end
        end

        archived_form_document = Api::V2::FormDocumentRepository.find(form_id:, tag: :archived)
        return render template: "forms/archived/show", locals: { form_name: archived_form_document.name }, status: :not_found if archived_form_document.present?
      end

      raise ActiveResource::ResourceNotFound, "Not Found"
    end

    def form_id
      params.require(:form_id)
    end
  end
end
