# frozen_string_literal: true

class Api::V1::Oauth::ApplicationsController < Api::BaseController
  before_action :authenticate_user!

  def create
    client_id = params[:client_id]
    account_id = params[:account_id]
    redirect_uri = params[:redirect_uri]

    unless client_id && account_id && redirect_uri
      render json: { error: 'Missing required parameters' }, status: :bad_request
      return
    end

    # Verificar se o usuário tem acesso admin à account
    account_user = current_user.account_users.find_by(account_id: account_id)
    unless account_user&.administrator?
      render json: { error: 'Access denied - admin role required' }, status: :forbidden
      return
    end

    account = Account.find_by(id: account_id)
    unless account
      render json: { error: 'Account not found' }, status: :not_found
      return
    end

    begin
      # Verificar se é uma aplicação RFC 7591 existente
      existing_app = OauthApplication.find_by(uid: client_id)
      
      if existing_app&.rfc7591_registered?
        # Vincular aplicação RFC7591 à account
        existing_app.update!(account_id: account_id)
        
        Rails.logger.debug "🔗 RFC 7591: Bound application #{existing_app.name} to account #{account.name}" if Rails.env.development?
        
        render json: { 
          message: 'Application bound to account successfully',
          application_id: existing_app.id,
          account_id: account_id
        }
      else
        # Criar nova aplicação dinâmica
        application = DynamicOauthService.create_or_find_application_for_account(
          client_id,
          account_id,
          current_user,
          redirect_uri
        )

        unless application
          render json: { error: 'Failed to create OAuth application' }, status: :unprocessable_entity
          return
        end

        Rails.logger.debug "✅ Dynamic OAuth: Created application #{application.name} for account #{account.name}" if Rails.env.development?

        render json: { 
          message: 'Application created successfully',
          application_id: application.id,
          account_id: account_id
        }
      end
    rescue => e
      Rails.logger.error "❌ OAuth Application Creation Error: #{e.message}"
      render json: { error: 'Failed to process OAuth application' }, status: :internal_server_error
    end
  end
end