# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/v1/accounts/conversations/:id/pin', type: :request do
  let(:account) { Account.create!(name: 'Spec Account') }
  let(:inbox) { Inbox.create!(account: account, name: 'Spec Inbox') }
  let(:contact) { Contact.create!(account: account, name: 'Spec Contact', email: 'spec@example.com') }
  let(:contact_inbox) { ContactInbox.create!(account: account, contact: contact, inbox: inbox) }
  let(:conversation) do
    Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox
    )
  end
  let(:service_token) { 'spec-service-token' }
  let(:headers) do
    {
      'X-Service-Token' => service_token,
      'account-id' => account.id.to_s
    }
  end

  before do
    ENV['EVOAI_CRM_API_TOKEN'] = service_token
  end

  after do
    ENV.delete('EVOAI_CRM_API_TOKEN')
    Current.reset
  end

  def json_response
    JSON.parse(response.body)
  end

  it 'pins conversation by setting custom_attributes' do
    post "/api/v1/accounts/conversations/#{conversation.id}/pin",
         headers: headers,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(conversation.reload.custom_attributes['pinned']).to be(true)
    expect(json_response.dig('data', 'custom_attributes', 'pinned')).to be(true)
  end
end

RSpec.describe 'POST /api/v1/accounts/conversations/:id/unpin', type: :request do
  let(:account) { Account.create!(name: 'Spec Account') }
  let(:inbox) { Inbox.create!(account: account, name: 'Spec Inbox') }
  let(:contact) { Contact.create!(account: account, name: 'Spec Contact', email: 'spec@example.com') }
  let(:contact_inbox) { ContactInbox.create!(account: account, contact: contact, inbox: inbox) }
  let(:conversation) do
    Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      custom_attributes: { 'pinned' => true }
    )
  end
  let(:service_token) { 'spec-service-token' }
  let(:headers) do
    {
      'X-Service-Token' => service_token,
      'account-id' => account.id.to_s
    }
  end

  before do
    ENV['EVOAI_CRM_API_TOKEN'] = service_token
  end

  after do
    ENV.delete('EVOAI_CRM_API_TOKEN')
    Current.reset
  end

  def json_response
    JSON.parse(response.body)
  end

  it 'unpins conversation by updating custom_attributes' do
    post "/api/v1/accounts/conversations/#{conversation.id}/unpin",
         headers: headers,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(conversation.reload.custom_attributes['pinned']).to be(false)
    expect(json_response.dig('data', 'custom_attributes', 'pinned')).to be(false)
  end
end

RSpec.describe 'POST /api/v1/accounts/conversations/:id/archive', type: :request do
  let(:account) { Account.create!(name: 'Spec Account') }
  let(:inbox) { Inbox.create!(account: account, name: 'Spec Inbox') }
  let(:contact) { Contact.create!(account: account, name: 'Spec Contact', email: 'spec@example.com') }
  let(:contact_inbox) { ContactInbox.create!(account: account, contact: contact, inbox: inbox) }
  let(:conversation) do
    Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox
    )
  end
  let(:service_token) { 'spec-service-token' }
  let(:headers) do
    {
      'X-Service-Token' => service_token,
      'account-id' => account.id.to_s
    }
  end

  before do
    ENV['EVOAI_CRM_API_TOKEN'] = service_token
  end

  after do
    ENV.delete('EVOAI_CRM_API_TOKEN')
    Current.reset
  end

  def json_response
    JSON.parse(response.body)
  end

  it 'archives conversation by setting custom_attributes' do
    post "/api/v1/accounts/conversations/#{conversation.id}/archive",
         headers: headers,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(conversation.reload.custom_attributes['archived']).to be(true)
    expect(json_response.dig('data', 'custom_attributes', 'archived')).to be(true)
  end
end

RSpec.describe 'POST /api/v1/accounts/conversations/:id/unarchive', type: :request do
  let(:account) { Account.create!(name: 'Spec Account') }
  let(:inbox) { Inbox.create!(account: account, name: 'Spec Inbox') }
  let(:contact) { Contact.create!(account: account, name: 'Spec Contact', email: 'spec@example.com') }
  let(:contact_inbox) { ContactInbox.create!(account: account, contact: contact, inbox: inbox) }
  let(:conversation) do
    Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      custom_attributes: { 'archived' => true }
    )
  end
  let(:service_token) { 'spec-service-token' }
  let(:headers) do
    {
      'X-Service-Token' => service_token,
      'account-id' => account.id.to_s
    }
  end

  before do
    ENV['EVOAI_CRM_API_TOKEN'] = service_token
  end

  after do
    ENV.delete('EVOAI_CRM_API_TOKEN')
    Current.reset
  end

  def json_response
    JSON.parse(response.body)
  end

  it 'unarchives conversation by updating custom_attributes' do
    post "/api/v1/accounts/conversations/#{conversation.id}/unarchive",
         headers: headers,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(conversation.reload.custom_attributes['archived']).to be(false)
    expect(json_response.dig('data', 'custom_attributes', 'archived')).to be(false)
  end
end
