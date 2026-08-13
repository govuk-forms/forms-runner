class ExitPage
  attr_reader :id, :heading, :markdown

  def initialize(id:, heading:, markdown:)
    @id = id
    @heading = heading
    @markdown = markdown
  end

  def self.from_form_document(form_document_exit_page)
    new(
      id: form_document_exit_page.id,
      heading: form_document_exit_page.heading,
      markdown: form_document_exit_page.markdown,
    )
  end

  def ==(other)
    super ||
      other.class == self.class &&
        other.id == id
  end
end
