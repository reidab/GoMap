class AddLastCurrentAtToLog < ActiveRecord::Migration
  def change
    add_column :log, :last_current_at, :datetime
  end
end
