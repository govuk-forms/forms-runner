class Api::V3::FormDocumentResource < ActiveResource::Base
  self.element_name = "form"
  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v3/"
  self.include_format_in_path = false

  has_many :steps, class_name: "Api::V2::StepResource"
  has_many :delivery_configurations, class_name: "Api::V2::DeliveryConfigurationResource"

  class << self
    def find_by_tag(form_id, tag, **options)
      return draft_form_document(form_id, **options) if tag == :draft

      latest_version = get("#{form_id}/versions/#{tag}", **options)["version"]
      find_by_version(form_id, latest_version, **options)
    end

    def find_by_version(form_id, version, **options)
      get("#{form_id}/versions/#{version}", **options)
    end

  private

    def draft_form_document(form_id, **options)
      get("#{form_id}/versions/draft", **options)
    end
  end
end
