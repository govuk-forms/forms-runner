class Api::V2::BrandRepository
  CACHE_TTL = 5.minutes
  # cached in place of a brand so that 404s from the API are not repeated for
  # every page load
  NOT_FOUND = "not_found".freeze

  class << self
    def find(brand_id)
      return nil if brand_id.blank?

      branding_from_api(brand_id) || BRANDING_CONFIG[brand_id]
    end

  private

    def branding_from_api(brand_id)
      branding = Rails.cache.fetch(cache_key(brand_id), expires_in: CACHE_TTL) do
        fetch_brand(brand_id)
      end

      branding == NOT_FOUND ? nil : branding
    rescue ActiveResource::ConnectionError, SocketError, SystemCallError => e
      Rails.logger.warn("Failed to fetch brand from the API - #{e.class.name}: #{e.message}", { brand_id: })
      nil
    end

    def fetch_brand(brand_id)
      brand = Api::V2::BrandResource.find(brand_id)
      branding_attributes(brand.attributes)
    rescue ActiveResource::ResourceNotFound
      NOT_FOUND
    end

    def cache_key(brand_id)
      "api/v2/brand/#{brand_id}"
    end

    # match the shape of the entries in config/branding.yml
    def branding_attributes(attributes)
      {
        "background_colour" => attributes["header_background_colour"],
        "border_colour" => attributes["border_colour"],
        "organisation_name" => attributes["name"],
        "organisation_url" => attributes["logo_link"],
        "copyright_holder" => attributes["copyright_holder"],
        "logo" => attributes["logo_path"],
        "favicon" => attributes["favicon_path"],
        "opengraph" => attributes["opengraph_image_path"],
      }
    end
  end
end
