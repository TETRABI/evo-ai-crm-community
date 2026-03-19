class ChangePhoneNumberUniquenessToAccountScoped < ActiveRecord::Migration[7.1]
  def up
    # Remove o índice único global de phone_number
    remove_index :channel_whatsapp, name: 'index_channel_whatsapp_on_phone_number'
    
    # Adiciona índice único composto por account_id e phone_number
    add_index :channel_whatsapp, [:account_id, :phone_number], unique: true, name: 'index_channel_whatsapp_on_account_id_and_phone_number'
  end

  def down
    # Remove o índice composto
    remove_index :channel_whatsapp, name: 'index_channel_whatsapp_on_account_id_and_phone_number'
    
    # Restaura o índice único global
    add_index :channel_whatsapp, :phone_number, unique: true, name: 'index_channel_whatsapp_on_phone_number'
  end
end

