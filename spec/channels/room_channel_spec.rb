# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoomChannel, type: :channel do
  let(:account) { Account.create!(name: 'Room Test Account') }
  let(:user) do
    u = User.create!(name: 'Agent', email: "room-#{SecureRandom.hex(4)}@test.com")
    AccountUser.create!(account: account, user: u)
    u
  end
  let(:web_channel) { Channel::WebWidget.create!(account: account, website_url: 'https://test.example.com') }
  let(:inbox) { Inbox.create!(account: account, name: 'Test Inbox', channel: web_channel) }
  let(:contact) { Contact.create!(account: account, name: 'Test Contact', email: "contact-#{SecureRandom.hex(4)}@test.com") }
  let(:contact_inbox) { ContactInbox.create!(inbox: inbox, contact: contact, source_id: "test-#{SecureRandom.hex(4)}") }

  before do
    allow(OnlineStatusTracker).to receive(:update_presence)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return([])
    allow(OnlineStatusTracker).to receive(:get_available_contacts).and_return([])
  end

  describe '#subscribed' do
    context 'with valid user pubsub_token' do
      it 'subscribes successfully' do
        InboxMember.create!(inbox: inbox, user: user)
        stub_connection(warden_user: nil)

        subscribe(account_id: account.id.to_s, user_id: user.id.to_s, pubsub_token: user.pubsub_token)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from(user.pubsub_token)
        expect(subscription).to have_stream_from("account_#{account.id}")
      end
    end

    context 'with valid contact pubsub_token' do
      it 'subscribes as contact' do
        stub_connection(warden_user: nil)

        subscribe(account_id: account.id.to_s, pubsub_token: contact_inbox.pubsub_token)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from(contact_inbox.pubsub_token)
      end
    end

    context 'with rotated token but valid warden session' do
      it 'falls back to warden user and uses current token' do
        InboxMember.create!(inbox: inbox, user: user)
        stub_connection(warden_user: user)

        subscribe(account_id: account.id.to_s, user_id: user.id.to_s, pubsub_token: 'stale-token')

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from(user.pubsub_token)
      end
    end

    context 'with invalid token and no warden session' do
      it 'rejects the subscription' do
        stub_connection(warden_user: nil)

        subscribe(account_id: account.id.to_s, user_id: '999', pubsub_token: 'invalid-token')

        expect(subscription).to be_rejected
      end
    end

    context 'with invalid token and mismatched warden user' do
      it 'rejects when warden user_id does not match params' do
        other_user = User.create!(name: 'Other', email: "other-#{SecureRandom.hex(4)}@test.com")
        stub_connection(warden_user: other_user)

        subscribe(account_id: account.id.to_s, user_id: user.id.to_s, pubsub_token: 'invalid-token')

        expect(subscription).to be_rejected
      end
    end
  end
end
