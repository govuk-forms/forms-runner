class FooterComponent::FooterComponentPreview < ViewComponent::Preview
  def default
    render(FooterComponent::View.new(mode: nil, form: nil))
  end

  def in_form_scope
    mode = Mode.new
    form = OpenStruct.new(id: 1, name: "test", form_slug: "test")
    render(FooterComponent::View.new(mode:, form:))
  end

  def with_custom_branding
    mode = Mode.new
    form = OpenStruct.new(id: 1,
                          name: "test",
                          form_slug: "test",
                          has_custom_branding?: true,
                          branding: Brand.new(copyright_holder: "Cheshire East Council"))
    render(FooterComponent::View.new(mode:, form:))
  end
end
