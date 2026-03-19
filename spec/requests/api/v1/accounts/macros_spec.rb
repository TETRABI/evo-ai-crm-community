# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe 'API::V1::Accounts::MacrosController', type: :request do
  let(:base_url) { 'http://auth.test' }
  let(:validate_url) { "#{base_url}/api/v1/auth/validate" }
  let(:token) { 'test-bearer-token' }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  let!(:account) { Account.create!(name: 'Spec Account') }
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:account_user) { AccountUser.create!(user: user, account: account) }

  around do |example|
    original_base_url = ENV['EVO_AUTH_SERVICE_URL']
    ENV['EVO_AUTH_SERVICE_URL'] = base_url
    Rails.cache.clear
    Current.reset
    example.run
    Rails.cache.clear
    Current.reset
    ENV['EVO_AUTH_SERVICE_URL'] = original_base_url
  end

  before do
    stub_request(:post, validate_url)
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          success: true,
          data: {
            user: { id: user.id, email: user.email },
            accounts: [{ id: account.id }]
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    permission_check_url = "#{base_url}/api/v1/users/#{user.id}/check_permission"
    stub_request(:post, permission_check_url)
      .with(headers: { 'account-id' => account.id.to_s })
      .to_return(
        status: 200,
        body: {
          success: true,
          data: { has_permission: true }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    put '/api/v1/profile/set_active_account',
        params: { profile: { account_id: account.id } },
        headers: headers,
        as: :json

    Current.account = account
    Current.user = user
  end

  describe 'POST /api/v1/macros' do
    context 'when creating a macro with global visibility' do
      it 'persists global visibility correctly' do
        post '/api/v1/macros',
             params: {
               name: 'Test Macro',
               visibility: 'global',
               actions: []
             },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response.dig('data', 'visibility')).to eq('global')

        created_macro = account.macros.find_by(name: 'Test Macro')
        expect(created_macro).to be_present
        expect(created_macro.visibility).to eq('global')
      end

      it 'persists personal visibility correctly' do
        post '/api/v1/macros',
             params: {
               name: 'Personal Macro',
               visibility: 'personal',
               actions: []
             },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response.dig('data', 'visibility')).to eq('personal')

        created_macro = account.macros.find_by(name: 'Personal Macro')
        expect(created_macro).to be_present
        expect(created_macro.visibility).to eq('personal')
      end
    end
  end

  describe 'PUT /api/v1/macros/:id' do
    let!(:macro) do
      account.macros.create!(
        name: 'Existing Macro',
        visibility: :personal,
        created_by: user,
        actions: []
      )
    end

    context 'when updating visibility to global' do
      it 'persists global visibility correctly' do
        put "/api/v1/macros/#{macro.id}",
            params: {
              name: 'Updated Macro',
              visibility: 'global',
              actions: []
            },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response.dig('data', 'visibility')).to eq('global')

        macro.reload
        expect(macro.visibility).to eq('global')
      end
    end
  end
end
