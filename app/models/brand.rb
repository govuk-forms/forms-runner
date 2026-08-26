class Brand
  ATTRIBUTES = %i[background_colour
                  border_colour
                  organisation_name
                  organisation_url
                  copyright_holder
                  logo
                  favicon
                  opengraph].freeze

  CACHE_TTL = 5.minutes
  # cached in place of the brand attributes so that 404s from the API are not
  # repeated for every page load
  NOT_FOUND = "not_found".freeze

  attr_reader(*ATTRIBUTES)

  def initialize(background_colour: nil, border_colour: nil, organisation_name: nil, organisation_url: nil,
                 copyright_holder: nil, logo: nil, favicon: nil, opengraph: nil)
    @background_colour = background_colour
    @border_colour = border_colour
    @organisation_name = organisation_name
    @organisation_url = organisation_url
    @copyright_holder = copyright_holder
    @logo = logo
    @favicon = favicon
    @opengraph = opengraph
  end

  class << self
    def find(brand_id)
      return nil if brand_id.blank?

      attributes = BRANDING_CONFIG[brand_id] || attributes_from_api(brand_id)
      from_attributes(attributes) if attributes
    end

    # attributes is a string-keyed hash in the shape of an entry in config/branding.yml
    def from_attributes(attributes)
      new(**attributes.symbolize_keys.slice(*ATTRIBUTES))
    end

  private

    def attributes_from_api(brand_id)
      attributes = Rails.cache.fetch(cache_key(brand_id), expires_in: CACHE_TTL) do
        fetch_brand(brand_id)
      end

      attributes == NOT_FOUND ? nil : attributes
    rescue ActiveResource::ConnectionError, SocketError, SystemCallError => e
      Rails.logger.warn("Failed to fetch brand from the API - #{e.class.name}: #{e.message}", { brand_id: })
      nil
    end

    def fetch_brand(brand_id)
      brand = Api::V2::BrandResource.find(brand_id)
      api_attributes(brand.attributes)
    rescue ActiveResource::ResourceNotFound
      NOT_FOUND
    end

    def cache_key(brand_id)
      "api/v2/brand/#{brand_id}"
    end

    # match the shape of the entries in config/branding.yml
    def api_attributes(attributes)
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
