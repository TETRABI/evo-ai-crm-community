# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActionCableBroadcastJob, type: :job do
  let(:account) { Account.create!(name: 'Broadcast Test Account') }

  describe '#perform' do
    it 'broadcasts event data to each member token' do
      tokens = %w[token-a token-b]
      data = { id: 1, content: 'hello', account_id: account.id }

      tokens.each do |token|
        expect(ActionCable.server).to receive(:broadcast).with(
          token,
          hash_including(event: 'message.created', data: hash_including(:content))
        )
      end

      described_class.perform_now(tokens, 'message.created', data)
    end

    it 'does nothing when members is blank' do
      expect(ActionCable.server).not_to receive(:broadcast)

      described_class.perform_now([], 'message.created', { account_id: account.id })
    end

    it 'fetches fresh conversation data for conversation update events' do
      contact = Contact.create!(account: account, name: 'BC', email: "bc-#{SecureRandom.hex(4)}@test.com")
      channel = Channel::WebWidget.create!(account: account, website_url: 'https://bc.example.com')
      inbox = Inbox.create!(account: account, name: 'BC Inbox', channel: channel)
      contact_inbox = ContactInbox.create!(inbox: inbox, contact: contact, source_id: "bc-#{SecureRandom.hex(4)}")
      conversation = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)

      expect(ActionCable.server).to receive(:broadcast).with(
        'token-x',
        hash_including(event: 'conversation.status_changed', data: hash_including(:id))
      )

      described_class.perform_now(
        ['token-x'],
        'conversation.status_changed',
        { id: conversation.id, account_id: account.id }
      )
    end
  end
end
