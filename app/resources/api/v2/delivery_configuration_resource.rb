class Api::V2::DeliveryConfigurationResource < ActiveResource::Base
  self.element_name = "delivery_configuration"
  self.site = Api::V2::FormDocumentResource.site
  self.prefix = Api::V2::FormDocumentResource.prefix_source
  self.include_format_in_path = false

  belongs_to :form
end
