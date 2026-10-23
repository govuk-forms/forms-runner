class AddDeliveryConfigurationToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :delivery_configurations, :jsonb
  end
end
