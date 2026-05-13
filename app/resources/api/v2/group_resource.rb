class Api::V2::GroupResource < ActiveResource::Base
  self.element_name = "group"
  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v2/forms/:form_id/"
  self.include_format_in_path = false

  def self.find(form_id)
    super(:one, from: "/api/v2/forms/#{form_id}/group")
  end
end
