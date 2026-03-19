class DropEmailTemplatesTable < ActiveRecord::Migration[7.1]
  def up
    drop_table :email_templates
  end

  def down
    create_table :email_templates, id: :uuid do |t|
      t.string :name, null: false
      t.text :body, null: false
      t.uuid :account_id
      t.integer :template_type, default: 1
      t.integer :locale, default: 0, null: false
      
      t.timestamps null: false
      
      t.index [:name, :account_id], unique: true, name: 'index_email_templates_on_name_and_account_id'
    end
  end
end
