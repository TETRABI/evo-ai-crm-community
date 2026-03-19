# frozen_string_literal: true

class Api::V1::Accounts::DynamicOauthController < Api::V1::Accounts::BaseController
  def available_accounts
    accounts = DynamicOauthService.available_accounts_for_user(current_user)

    render json: {
      success: true,
      data: {
        user_id: current_user.id,
        available_accounts: accounts,
        usage_example: {
          authorization_url: "#{request.base_url}/oauth/authorize",
          parameters: {
            response_type: 'code',
            client_id: '{dynamic_client_id}',
            redirect_uri: '{your_callback_url}',
            scope: 'admin',
            state: '{optional_state}'
          },
          example_url: accounts.first ?
            "#{request.base_url}/oauth/authorize?response_type=code&client_id=#{accounts.first[:dynamic_client_id]}&redirect_uri=https://your-app.com/callback&scope=admin&state=example" :
            nil
        }
      }
    }
  end

  def validate_dynamic_client
    client_id = params[:client_id]

    unless DynamicOauthService.is_dynamic_client_id?(client_id)
      return render json: {
        success: false,
        error: 'Invalid dynamic client ID format',
        expected_format: 'dynamic_account_{account_id}'
      }, status: :bad_request
    end

    account_id = DynamicOauthService.extract_account_id(client_id)
    account_user = current_user.account_users.find_by(account_id: account_id)

    if account_user&.administrator?
      account = Account.find_by(id: account_id)
      render json: {
        success: true,
        data: {
          client_id: client_id,
          account_id: account_id,
          account_name: account&.name,
          user_role: account_user.role,
          can_authorize: true
        }
      }
    else
      render json: {
        success: false,
        error: 'You do not have administrator access to this account',
        client_id: client_id,
        account_id: account_id,
        can_authorize: false
      }, status: :forbidden
    end
  end
end
