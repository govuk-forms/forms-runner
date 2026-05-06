class AddFailureDetailsToDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :deliveries, :failure_details, :jsonb
  end
end
