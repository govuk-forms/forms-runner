class AddLocaleToIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :incomplete_submissions, :locale, :string, default: "en", null: false, comment: "The language used to complete the form in ISO 2 letter format. Normally either 'en' or 'cy'"
  end
end
