class AddDeliveryMethodAndFormatsToDeliveries < ActiveRecord::Migration[8.1]
  def change
    change_table :deliveries, bulk: true do |t|
      t.string :delivery_method, null: true
      t.string :formats, array: true, null: true
    end
  end
end
