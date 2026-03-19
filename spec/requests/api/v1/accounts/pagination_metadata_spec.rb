# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pagination Metadata', type: :request do
  let(:account) { Account.create!(name: 'Spec Account') }
  let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
  let(:service_token) { 'spec-service-token' }
  let(:headers) do
    {
      'X-Service-Token' => service_token,
      'account-id' => account.id.to_s
    }
  end

  before do
    ENV['EVOAI_CRM_API_TOKEN'] = service_token
    AccountUser.create!(account: account, user: user)
    Current.account = account
    Current.user = user
  end

  after do
    ENV.delete('EVOAI_CRM_API_TOKEN')
    Current.reset
  end

  def json_response
    JSON.parse(response.body)
  end

  describe 'GET /api/v1/teams' do
    before do
      25.times { |i| Team.create!(account: account, name: "Team #{i}") }
    end

    context 'when using pageSize parameter (camelCase)' do
      it 'returns pagination metadata with correct pageSize' do
        get '/api/v1/teams', params: { page: 1, pageSize: 10 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(10)
        expect(json['meta']['pagination']['page']).to eq(1)
        expect(json['data'].length).to eq(10)
      end
    end

    context 'when using page_size parameter (snake_case)' do
      it 'returns pagination metadata with correct pageSize' do
        get '/api/v1/teams', params: { page: 1, page_size: 15 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(15)
        expect(json['meta']['pagination']['page']).to eq(1)
        expect(json['data'].length).to eq(15)
      end
    end

    context 'when using per_page parameter' do
      it 'returns pagination metadata with correct pageSize' do
        get '/api/v1/teams', params: { page: 1, per_page: 5 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(5)
        expect(json['meta']['pagination']['page']).to eq(1)
        expect(json['data'].length).to eq(5)
      end
    end

    context 'when no pagination parameters provided' do
      it 'returns pagination metadata with default pageSize' do
        get '/api/v1/teams', headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(20)
        expect(json['meta']['pagination']['page']).to eq(1)
      end
    end

    context 'when pageSize is 0' do
      it 'guards against invalid pageSize and uses default minimum of 1' do
        get '/api/v1/teams', params: { page: 1, pageSize: 0 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(1)
      end
    end

    context 'when pageSize is negative' do
      it 'guards against invalid pageSize and uses default minimum of 1' do
        get '/api/v1/teams', params: { page: 1, pageSize: -1 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(1)
      end
    end

    context 'when page_size is 0' do
      it 'guards against invalid page_size and uses default minimum of 1' do
        get '/api/v1/teams', params: { page: 1, page_size: 0 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(1)
      end
    end
  end

  describe 'GET /api/v1/labels' do
    before do
      30.times { |i| Label.create!(account: account, title: "label_#{i}") }
    end

    context 'when using pageSize parameter' do
      it 'returns pagination metadata with correct pageSize' do
        get '/api/v1/labels', params: { page: 1, pageSize: 12 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(12)
        expect(json['meta']['pagination']['page']).to eq(1)
        expect(json['data'].length).to eq(12)
      end
    end

    context 'when using page_size parameter' do
      it 'returns pagination metadata with correct pageSize' do
        get '/api/v1/labels', params: { page: 2, page_size: 8 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(8)
        expect(json['meta']['pagination']['page']).to eq(2)
      end
    end

    context 'when per_page is 0' do
      it 'guards against invalid per_page and uses default minimum of 1' do
        get '/api/v1/labels', params: { page: 1, per_page: 0 }, headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json['meta']['pagination']['pageSize']).to eq(1)
      end
    end
  end
end
