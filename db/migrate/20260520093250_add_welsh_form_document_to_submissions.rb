class AddWelshFormDocumentToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :welsh_form_document, :jsonb
  end
end
