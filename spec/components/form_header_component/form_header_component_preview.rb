class FormHeaderComponent::FormHeaderComponentPreview < ViewComponent::Preview
  def default
    mode = Mode.new
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, mode:))
  end

  def preview_draft
    mode = Mode.new("preview-draft")
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, mode:))
  end

  def preview_archived
    mode = Mode.new("preview-archived")
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, mode:))
  end

  def preview_live
    mode = Mode.new("preview-live")
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, mode:))
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

    mode = Mode.new
    current_context = OpenStruct.new(form:)
    render(FormHeaderComponent::View.new(current_context:, mode:))
  end
end
