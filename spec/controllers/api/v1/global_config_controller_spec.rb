require 'rails_helper'

RSpec.describe Api::V1::GlobalConfigController, type: :controller do
  before do
    # Full stub to avoid DB dependency
    allow(GlobalConfigService).to receive(:load).and_return(nil)
  end

  describe 'GET #show' do
    it 'returns public config without authentication' do
      get :show, format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'includes recaptchaSiteKey in the response' do
      allow(GlobalConfigService).to receive(:load).with('RECAPTCHA_SITE_KEY', nil).and_return('6Lc_test_key')

      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['recaptchaSiteKey']).to eq('6Lc_test_key')
    end

    it 'includes clarityProjectId in the response' do
      allow(GlobalConfigService).to receive(:load).with('CLARITY_PROJECT_ID', nil).and_return('clarity_test_id')

      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['clarityProjectId']).to eq('clarity_test_id')
    end

    it 'returns nil for unconfigured recaptchaSiteKey' do
      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['recaptchaSiteKey']).to be_nil
    end

    it 'returns nil for unconfigured clarityProjectId' do
      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['clarityProjectId']).to be_nil
    end
  end
end
