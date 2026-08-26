FactoryBot.define do
  factory :brand, class: "Brand" do
    initialize_with { new(**attributes) }

    background_colour { "#ffffff" }
    border_colour { "#00703c" }
    organisation_name { "Weatherfield Borough Council" }
    organisation_url { "https://www.weatherfield.example.com" }
    copyright_holder { "Weatherfield Borough Council" }
    logo { "/assets/brands/weatherfield/logo-abc123.png" }
    favicon { "/assets/brands/weatherfield/favicon-abc123.ico" }
    opengraph { "/assets/brands/weatherfield/opengraph-image-abc123.jpg" }

    trait :without_assets do
      logo { nil }
      favicon { nil }
      opengraph { nil }
    end
  end
end
