class Brand
  ATTRIBUTES = %i[background_colour
                  border_colour
                  organisation_name
                  organisation_url
                  copyright_holder
                  logo
                  favicon
                  opengraph].freeze

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

  def self.find(brand_id)
    return nil if brand_id.blank?

    attributes = BRANDING_CONFIG[brand_id]
    from_attributes(attributes) if attributes
  end

  # attributes is a string-keyed hash in the shape of an entry in config/branding.yml
  def self.from_attributes(attributes)
    new(**attributes.symbolize_keys.slice(*ATTRIBUTES))
  end
end
