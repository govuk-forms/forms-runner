FactoryBot.define do
  factory :brand, class: Api::V2::BrandResource do
    name { "Weatherfield Borough Council" }
    slug { "weatherfield" }
    header_background_colour { "#ffffff" }
    border_colour { "#00703c" }
    logo_alt_text { "Weatherfield Borough Council" }
    logo_link { "https://www.weatherfield.example.com" }
    copyright_holder { "Weatherfield Borough Council" }
    logo_path { "/assets/brands/weatherfield/logo-abc123.png" }
    favicon_path { "/assets/brands/weatherfield/favicon-abc123.ico" }
    opengraph_image_path { "/assets/brands/weatherfield/opengraph-image-abc123.jpg" }

    trait :without_assets do
      logo_path { nil }
      favicon_path { nil }
      opengraph_image_path { nil }
    end

    initialize_with { new(attributes) }
  end
end
