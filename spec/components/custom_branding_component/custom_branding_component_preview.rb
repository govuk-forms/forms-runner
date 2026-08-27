class CustomBrandingComponent::CustomBrandingComponentPreview < ViewComponent::Preview
  def default
    render(CustomBrandingComponent::View.new)
  end

  def without_custom_branding
    form = OpenStruct.new(id: 1,
                          name: "test_form_name",
                          form_slug: "test",
                          has_custom_branding?: false)

    render(CustomBrandingComponent::View.new(form:))
  end

  def with_custom_branding
    form = OpenStruct.new(id: 1,
                          name: "test_form_name",
                          form_slug: "test",
                          has_custom_branding?: true,
                          branding: Brand.new(
                            background_colour: "#ffffff",
                            border_colour: "#00703c",
                            organisation_name: "Weatherfield Borough Council",
                            organisation_url: "https://www.weatherfield.example.com",
                            logo: "/images/govuk-icon-180.png",
                          ))

    render(CustomBrandingComponent::View.new(form:))
  end
end
