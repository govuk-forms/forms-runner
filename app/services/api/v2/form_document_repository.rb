class Api::V2::FormDocumentRepository
  class << self
    def find(form_id:, tag:, language: :en)
      return nil unless form_id.to_s =~ /^[[:alnum:]]+$/

      begin
        form_document_json = Api::V2::FormDocumentResource.get(form_id, tag, **options_for_language(language))
        Api::V2::FormDocumentResource.new(form_document_json)
      rescue ActiveResource::ResourceNotFound
        nil
      end
    end

    def find_with_mode(form_id:, mode:, language: :en)
      find(form_id:, tag: mode.tag, language:)
    end

  private

    # Don't include English in the options hash as it's the default
    def options_for_language(language)
      return {} if language.blank? || language.to_sym == :en

      { language: language.to_sym }
    end
  end
end
