class Api::V1::AuthController < ApplicationController
  include EvoAuthConcern

  skip_before_action :verify_authenticity_token, raise: false
  skip_before_action :authenticate_with_evo_auth!, except: [:me, :logout], raise: false

  def login
    email = params[:email]
    password = params[:password]

    if email.blank? || password.blank?
      error_response(ApiErrorCodes::MISSING_REQUIRED_FIELD, 'Email and password are required', status: :bad_request)
      return
    end

    auth_service = EvoAuthService.new
    result = auth_service.authenticate(email, password)

    if result[:success]
      # Store token in session for future requests
      session[:evo_auth_token] = result[:token]

      success_response(
        data: {
          access_token: result[:token],
          user: result[:user],
          accounts: result[:accounts]
        },
        message: 'Login successful'
      )
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unauthorized
    end
  end

  def register
    user_params = params.require(:user).permit(:email, :password, :name)
    account_name = params.dig(:account, :name)

    auth_service = EvoAuthService.new
    result = auth_service.register(
      user_params[:email],
      user_params[:password],
      user_params[:name],
      account_name
    )

    if result[:success]
      # Store token in session
      session[:evo_auth_token] = result[:token]

      render json: {
        success: true,
        data: {
          access_token: result[:token],
          user: result[:user],
          account: result[:account]
        }
      }
    else
      render json: {
        success: false,
        error: result[:error],
        errors: result[:errors]
      }, status: :unprocessable_entity
    end
  end

  def me
    render json: {
      success: true,
      data: {
        user: current_user.as_json(
          only: [:id, :email, :name, :display_name, :availability],
          include: {
            account_users: {
              only: [:id, :role, :availability],
              include: {
                account: {
                  only: [:id, :name, :domain, :status]
                }
              }
            }
          }
        ),
        current_account: current_account&.as_json(
          only: [:id, :name, :domain, :status, :locale]
        ),
        accounts: current_user.accounts.active.as_json(
          only: [:id, :name, :domain, :status]
        )
      }
    }
  end

  def logout
    token = evo_auth_token

    if token.present?
      auth_service = EvoAuthService.new
      auth_service.logout(token)
    end

    session[:evo_auth_token] = nil
    Current.user = nil
    Current.account = nil
    Current.account_user = nil

    render json: { success: true, message: 'Logged out successfully' }
  end

  def reset_password
    email = params[:email]

    if email.blank?
      render json: { error: 'Email is required' }, status: :bad_request
      return
    end

    auth_service = EvoAuthService.new
    result = auth_service.reset_password(email)

    render json: result
  end

  def update_password
    reset_token = params[:reset_token]
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    if [reset_token, password, password_confirmation].any?(&:blank?)
      render json: { error: 'All fields are required' }, status: :bad_request
      return
    end

    auth_service = EvoAuthService.new
    result = auth_service.update_password(reset_token, password, password_confirmation)

    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def refresh
    refresh_token = params[:refresh_token] || session[:evo_refresh_token]

    if refresh_token.blank?
      render json: { error: 'Refresh token required' }, status: :bad_request
      return
    end

    auth_service = EvoAuthService.new
    result = auth_service.refresh_token(refresh_token)

    if result[:success]
      session[:evo_auth_token] = result[:token]
      session[:evo_refresh_token] = result[:refresh_token]

      render json: {
        success: true,
        data: {
          access_token: result[:token],
          refresh_token: result[:refresh_token]
        }
      }
    else
      render json: result, status: :unauthorized
    end
  end

  def switch_account
    account_id = params[:account_id]

    if account_id.blank?
      render json: { error: 'Account ID is required' }, status: :bad_request
      return
    end

    account = current_user.accounts.find_by(id: account_id)

    unless account
      render json: { error: 'Account not found or access denied' }, status: :forbidden
      return
    end

    # Update current context
    Current.account = account
    Current.account_user = current_user.account_users.find_by(account: account)

    render json: {
      success: true,
      data: {
        account: account.as_json(only: [:id, :name, :domain, :status, :locale]),
        account_user: Current.account_user.as_json(only: [:id, :role, :availability])
      }
    }
  end
end
