class Api::V1::Accounts::Integrations::AppsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:index, :show]
  before_action :fetch_apps, only: [:index]
  before_action :fetch_app, only: [:show]

  def index
    success_response(
      data: IntegrationAppSerializer.serialize_collection(@apps, account: Current.account),
      message: 'Integration apps retrieved successfully'
    )
  end

  def show
    success_response(
      data: IntegrationAppSerializer.serialize(@app, account: Current.account),
      message: 'Integration app retrieved successfully'
    )
  end

  private

  def fetch_apps
    @apps = Integrations::App.all.select { |app| app.active?(Current.account) }
  end

  def fetch_app
    @app = Integrations::App.find(id: params[:id])
  end
end
