class AddPageIdToChannelInstagrams < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_instagrams, :page_id, :string
    add_index :channel_instagrams, :page_id, where: 'page_id IS NOT NULL'
  end
end
