class AddConfirmationToUsersAndAgencyUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :confirmed_at, :datetime
    add_column :users, :invited_at, :datetime
    add_column :agency_users, :confirmed_at, :datetime
    add_column :agency_users, :invited_at, :datetime
  end
end
