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
                            "background_colour" => "#ffffff",
                            "border_colour" => "#ff0000",
                            "organisation_name" => "Summerisle Island Council",
                            "organisation_url" => "https://www.summerisle.gov.uk",
                            "logo" => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHgAAAAqCAMAAABP/G8cAAAAJFBMVEX+///v8u7W6d3o17m93r7Zz4Wfz6CRxduBvnzQfJlYq1kbjBtQ6hxcAAACsUlEQVR42u3U4W7jRgxF4XPvcCiKfP/37a4txEiwm3WA1imKfj8MYQTjiIQt/mXENwnxPdJ8jy2+hbr4DtrVwTfY++yD19tr+zz/rn+XQjxnLXb4NFxyfki+RBPcxQRP0SZqcR5cajKym69JfzW8Vsb+GRY3mgIQSiASZ3QH1SWUrk6q20B2JzhVSRpVd97D2V38QZV17vO0uZsxAB5BDzHTPdM1he7XUzNQUzVJzkxrkpnqsSfIqZz+Q3cD2qf82NVMB1e48QRMQw2ahB7wyGOouY+oCY9AeIK5vv57qi1AtbC5KGum38IxgknIkca3MzzK6e4ZcriFmemEGF97Mb+X1gKde2O/uzF+TGyYusLBIxw/mBzdw66ekceajB8+6wZroVOufZgbBVzPzbvwx4mvXT4mBpj0mAk+lQlanAuxD+48U1HTMJ09Tfx6YtNT0f0W9mTU2BPUVNSI34gE2OcC483Ffb0/YqaqcAsqIRq1r+e9Hc50EA3QpmYmcBvys1eQCoDzBMyxeZUMgHXuBTqOtXiJa2CdsIUOsYDXDXwuYEmCpReFdQ0MbAu+sms9f/qREt5ihw1s3nMXQCYPLkDVHXwU7mfKDoBlAFt7/WLkTiKdpUwpMlBW3c8dzsDGRCbKtD1PhQ3oPARY1hbaH8Phjlu4yxPtuoXd95sdmWpNtqsi0/18eF2XvlW3+DhxlzNdVS4qEheoARVRmZSazAbqybBu4XPBISTWYi/emZSzMzuj3HRU3BJdimhVZkWryei0y/N8+DxPfIBYe7H2xx+Xu8Lh7lSSju4E1N0RXeh+I+yfByqeDfNz4sPoHtbmH3eFETpA0tKCrReEzZ1v4b3XgvXSsG/htfWicPIIIy/xmjCpx6qR4WVhc3eArvCGV+4aZAGsxSuEeaPr83//AX8BngYVsMuf6BgAAAAASUVORK5CYII=",
                          })

    mode = Mode.new
    current_context = OpenStruct.new(form:)
    render(FormHeaderComponent::View.new(current_context:, mode:))
  end
end
