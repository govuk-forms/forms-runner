class Api::V3::FormsResource < ActiveResource::Base
  self.element_name = "form"
  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v3/"
  self.include_format_in_path = false

  class << self
    def with_delivery_schedule(delivery_schedule, **options)
      forms_with_delivery_schedule = where(delivery_schedule:, **options)

      forms_with_delivery_schedule.map do |form|
        { form_id: form.form_id, state: form.state }
      end
    end
  end
end
