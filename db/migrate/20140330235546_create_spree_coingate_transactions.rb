class CreateSpreeCoingateTransactions < ActiveRecord::Migration
  def change
    create_table :spree_coingate_transactions do |t|
    	t.string :order_id
    	t.string :secret_token
    end
  end
end
