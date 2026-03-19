# frozen_string_literal: true

class CreateScheduledActionTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_action_templates do |t|
      t.uuid :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :action_type, null: false, limit: 50
      t.integer :default_delay_minutes
      t.jsonb :payload, null: false, default: {}
      t.boolean :is_default, default: false
      t.boolean :is_public, default: false
      t.uuid :created_by, null: false

      t.timestamps
    end

    add_index :scheduled_action_templates, :account_id
    add_index :scheduled_action_templates, :action_type
    add_index :scheduled_action_templates, [:account_id, :is_default], name: 'idx_templates_account_default'
    add_index :scheduled_action_templates, [:account_id, :is_public], name: 'idx_templates_account_public'

    add_foreign_key :scheduled_action_templates, :accounts, on_delete: :cascade
    add_foreign_key :scheduled_action_templates, :users, column: :created_by, on_delete: :cascade
  end
end
