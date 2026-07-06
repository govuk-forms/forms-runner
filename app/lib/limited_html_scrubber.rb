class LimitedHtmlScrubber < Rails::Html::PermitScrubber
  def initialize(allow_headings: false, for_email: false)
    super()

    self.tags = ["a", "ol", "ul", "li", "p", "br", *(%w[h2 h3] if allow_headings), *(%w[table tr td] if for_email)]

    self.attributes = ["href", "class", "rel", "target", "title", *(%w[style] if for_email)]
  end
end
