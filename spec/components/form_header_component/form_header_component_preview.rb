class FormHeaderComponent::FormHeaderComponentPreview < ViewComponent::Preview
  def default
    mode = Mode.new
    auth_service = OpenStruct.new(logged_in?: false)
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, auth_service:, mode:))
  end

  def preview_draft
    mode = Mode.new("preview-draft")
    auth_service = OpenStruct.new(logged_in?: false)
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, auth_service:, mode:))
  end

  def preview_archived
    mode = Mode.new("preview-archived")
    auth_service = OpenStruct.new(logged_in?: false)
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, auth_service:, mode:))
  end

  def preview_live
    mode = Mode.new("preview-live")
    auth_service = OpenStruct.new(logged_in?: false)
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, auth_service:, mode:))
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
    auth_service = OpenStruct.new(logged_in?: false)
    current_context = OpenStruct.new(form:)
    render(FormHeaderComponent::View.new(current_context:, auth_service:, mode:))
  end

  def signed_in_to_one_login
    mode = Mode.new
    auth_service = OpenStruct.new(logged_in?: true)
    current_context = OpenStruct.new(form: OpenStruct.new(id: 1, name: "test", form_slug: "test"))
    render(FormHeaderComponent::View.new(current_context:, auth_service:, mode:))
  end
end
