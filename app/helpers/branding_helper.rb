module BrandingHelper
  def branding_asset_url(path)
    "#{Settings.forms_runner.base_url}#{path}"
  end
end
