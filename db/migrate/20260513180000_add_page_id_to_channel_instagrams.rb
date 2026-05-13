class AddPageIdToChannelInstagrams < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_instagram, :page_id, :string
    add_index :channel_instagram, :page_id, where: 'page_id IS NOT NULL'
  end
end
