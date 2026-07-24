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
                          branding: {
                            "background_colour" => "white",
                            "border_colour" => "#206c49",
                            "organisation_name" => "Cheshire East Council",
                            "organisation_url" => "https://www.cheshireeast.gov.uk",
                            "logo" => "/brand_assets/cheshire-east/logo.png",
                          })

    render(CustomBrandingComponent::View.new(form:))
  end
end
