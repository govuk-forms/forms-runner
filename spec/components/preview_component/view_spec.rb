require "rails_helper"

RSpec.describe PreviewComponent::View, type: :component do
  it "shows in preview_draft" do
    mode = Mode.new("preview-draft")
    render_inline(described_class.new(mode:, question_edit_link: "https://gov.uk"))
    expect(page).to have_selector(".govuk-phase-banner")
    expect(page).to have_selector(".govuk-tag--yellow", text: I18n.t("mode.phase_banner_tag_preview-draft"))
    expect(page).to have_content(I18n.t("mode.phase_banner_text_preview-draft"))
    expect(page).to have_link(I18n.t("mode.phase_banner_text_preview-draft_edit_link", href: "https://gov.uk"))
  end

  it "shows in preview_archived" do
    mode = Mode.new("preview-archived")
    render_inline(described_class.new(mode:))
    expect(page).to have_selector(".govuk-phase-banner")
    expect(page).to have_selector(".govuk-tag--orange", text: I18n.t("mode.phase_banner_tag_preview-archived"))
    expect(page).to have_content(I18n.t("mode.phase_banner_text_preview-archived"))
  end

  it "shows in preview_live" do
    mode = Mode.new("preview-live")
    render_inline(described_class.new(mode:))
    expect(page).to have_selector(".govuk-phase-banner")
    expect(page).to have_selector(".govuk-tag--teal", text: I18n.t("mode.phase_banner_tag_preview-live"))
    expect(page).to have_content(I18n.t("mode.phase_banner_text_preview-live"))
  end

  it "does not show in live" do
    mode = Mode.new("form")
    render_inline(described_class.new(mode:))
    expect(page).not_to have_selector(".govuk-phase-banner")
  end
end
