# frozen_string_literal: true

class Api::V1::Oauth::AccountsController < Api::BaseController
  before_action :authenticate_user!

  def index
    # Retornar contas onde o usuário é admin (pode autorizar apps OAuth)
    accounts = current_user.account_users
                          .joins(:account)
                          .where(role: 'account_owner')
                          .includes(:account)
                          .map do |account_user|
      {
        account_id: account_user.account.id,
        account_name: account_user.account.name,
        dynamic_client_id: DynamicOauthService.generate_dynamic_client_id(account_user.account.id)
      }
    end

    success_response(data: accounts, message: 'OAuth accounts retrieved successfully')
  end
end