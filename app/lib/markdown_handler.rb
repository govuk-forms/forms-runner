module MarkdownHandler
  def self.erb
    @erb ||= ActionView::Template.registered_template_handler(:erb)
  end

  def self.call(template)
    erb.call(template)
  end
end

ActionView::Template.register_template_handler :md, MarkdownHandler
