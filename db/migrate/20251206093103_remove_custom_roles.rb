# frozen_string_literal: true

class RemoveCustomRoles < ActiveRecord::Migration[7.1]
  def up
    # Remove foreign key constraint if it exists
    if foreign_key_exists?(:account_users, :custom_roles)
      remove_foreign_key :account_users, :custom_roles
    end

    # Remove index if it exists
    if index_exists?(:account_users, :custom_role_id)
      remove_index :account_users, :custom_role_id
    end

    # Remove column from account_users if it exists
    if column_exists?(:account_users, :custom_role_id)
      remove_column :account_users, :custom_role_id, :uuid
    end

    # Drop table if it exists
    drop_table :custom_roles, if_exists: true
  end

  def down
    # Recreate table (if needed for rollback)
    create_table :custom_roles, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.jsonb :permissions, default: []
      t.timestamps
    end

    add_index :custom_roles, [:account_id, :name], unique: true

    # Recreate column in account_users
    add_column :account_users, :custom_role_id, :uuid
    add_index :account_users, :custom_role_id
    add_foreign_key :account_users, :custom_roles, column: :custom_role_id
  end
end

