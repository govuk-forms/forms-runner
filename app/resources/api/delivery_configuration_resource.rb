class Api::DeliveryConfigurationResource < ActiveResource::Base
  self.element_name = "delivery_configuration"
  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v3/"
  self.include_format_in_path = false

  belongs_to :form

  def self.from_form(form_id, draft: false)
    state = draft ? "draft" : "current"

    find(:all, from: "/api/v3/forms/#{form_id}/delivery-configurations/#{state}")
  end
end
