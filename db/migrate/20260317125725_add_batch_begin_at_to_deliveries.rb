class AddBatchBeginAtToDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :deliveries, :batch_begin_at, :datetime
  end
end
