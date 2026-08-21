class Api::V2::BrandResource < ActiveResource::Base
  self.element_name = "brand"
  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v2/"
  self.include_format_in_path = false

  def self.find(brand_id)
    super(:one, from: "/api/v2/brands/#{brand_id}")
  end
end
