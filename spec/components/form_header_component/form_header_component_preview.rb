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
                          branding: {
                            "background_colour" => "white",
                            "border_colour" => "#206c49",
                            "organisation_name" => "Cheshire East Council",
                            "organisation_url" => "https://www.cheshireeast.gov.uk",
                            "logo" => "/brand_assets/cheshire-east/logo.png",
                          })

    mode = Mode.new
    current_context = OpenStruct.new(form:)
    render(FormHeaderComponent::View.new(current_context:, mode:))
  end
end
