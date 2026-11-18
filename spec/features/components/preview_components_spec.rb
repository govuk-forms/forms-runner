require "rails_helper"

describe "Previewing components", type: :feature do
  it "checks all component previews for axe errors" do
    visit "/preview/"
    expect(page).to have_text("Preview")
    links = page.all("li > a").map { |a| a["href"] }
    links.each do |link|
      visit link
      skipping = link.include?("file_component") ? [AxeFeatureHelpers::LABEL_CONTENT_NAME_MISMATCH] : []
      expect_component_to_have_no_axe_errors(page, skipping:)
    end
  end

  it "checks GDS Transport font is available" do
    visit "/preview/"
    expect(page).to have_text("Preview")
    font_loaded = evaluate_script("document.fonts.check('12px GDS Transport')")

    expect(font_loaded).to be true
  end
end
