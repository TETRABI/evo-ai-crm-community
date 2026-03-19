# frozen_string_literal: true

require 'cgi'

class OauthAuthorizationController < Doorkeeper::AuthorizationsController
  include DynamicOauthHelper

  # Skip Doorkeeper's authenticate_resource_owner! for our setup
  skip_before_action :authenticate_resource_owner!, only: [:new, :create]

  before_action :setup_dynamic_application, only: [:new, :create]
  before_action :check_return_from_login, only: [:new]
  before_action :ensure_authenticated_for_valid_apps, only: [:new, :create]

  # Método new herdado do Doorkeeper funcionará normalmente

  private

  def ensure_authenticated_for_valid_apps
    client_id = params[:client_id]
    return unless client_id

    # Check if it's a legitimate OAuth app (not RFC7591)
    existing_app = OauthApplication.find_by(uid: client_id)
    if existing_app && !existing_app.rfc7591_registered?
      # For legitimate apps, ensure user is authenticated
      current_resource_owner = doorkeeper_resource_owner
      unless current_resource_owner
        # Redirect to frontend login page and store return URL
        session[:return_to] = request.url
        encoded_return_url = CGI.escape(request.url)
        frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')
        redirect_to "#{frontend_url}/login?returnUrl=#{encoded_return_url}" and return
      end
    end

    # Special handling for MCP applications
    if existing_app && existing_app.rfc7591_registered? && is_mcp_application?(existing_app)
      current_resource_owner = doorkeeper_resource_owner
      unless current_resource_owner
        # For MCP apps, redirect to login but don't require account selection
        session[:return_to] = request.url
        encoded_return_url = CGI.escape(request.url)
        frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')
        redirect_to "#{frontend_url}/login?returnUrl=#{encoded_return_url}" and return
      end

      # Auto-bind MCP app to first available account for user
      if existing_app.account_id.nil?
        auto_bind_mcp_app_to_account(existing_app, current_resource_owner)
      end
    end
  end

  def check_return_from_login
    # Se o usuário acabou de fazer login e tem return_to na sessão
    if session[:return_to] && current_user
      return_url = session[:return_to]
      session.delete(:return_to)

      # Redirecionar para a URL original
      if Rails.env.development?
        Rails.logger.debug "🔄 User returned from login, redirecting to: #{return_url}"
      end

      redirect_to(return_url) and return
    end
  end

  def setup_dynamic_application
    client_id = params[:client_id]
    selected_account_id = params[:selected_account_id]

    Rails.logger.debug "🔍 OAuth Debug: client_id=#{client_id}, params=#{params.to_unsafe_h}" if Rails.env.development?

    return unless client_id

    # Verificar se é uma aplicação OAuth legítima (não dinâmica)
    existing_app = OauthApplication.find_by(uid: client_id)
    Rails.logger.debug "🔍 OAuth Debug: existing_app=#{existing_app&.name}, rfc7591=#{existing_app&.rfc7591_registered?}, account_id=#{existing_app&.account_id}" if Rails.env.development?

    if existing_app && !existing_app.rfc7591_registered?
      # Aplicação OAuth legítima - deixar Doorkeeper processar normalmente (não redirecionar)
      Rails.logger.debug "⏭️ OAuth App legítima encontrada: #{existing_app.name} - deixando Doorkeeper processar" if Rails.env.development?
      return
    end

    # Se é RFC7591 MAS já tem account_id, deixar Doorkeeper processar normalmente
    if existing_app && existing_app.rfc7591_registered? && existing_app.account_id.present?
      Rails.logger.debug "⏭️ RFC7591 App já vinculada à account #{existing_app.account_id} - deixando Doorkeeper processar" if Rails.env.development?
      return
    end

    # Verificar se usuário está logado para aplicações dinâmicas/RFC7591
    current_resource_owner = doorkeeper_resource_owner
    unless current_resource_owner
      # Para aplicações dinâmicas, redirecionar para frontend
      session[:return_to] = request.url
      encoded_oauth_url = CGI.escape(request.url)
      frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')
      Rails.logger.debug "🔄 Aplicação dinâmica - redirecionando para frontend: #{frontend_url}/auth?oauth_url=#{encoded_oauth_url}" if Rails.env.development?
      redirect_to "#{frontend_url}/auth?oauth_url=#{encoded_oauth_url}"
      return
    end

    # Se tem account selecionada, processar vinculação
    if selected_account_id.present?
      redirect_uri = params[:redirect_uri]

      # Verificar se é uma aplicação RFC 7591 que precisa ser vinculada
      existing_app = OauthApplication.find_by(uid: client_id)
      if existing_app&.rfc7591_registered?
        success = bind_rfc7591_app_to_account(existing_app, selected_account_id.to_i, current_resource_owner)
        unless success
          render_dynamic_authorization_error
          return
        end
        if Rails.env.development?
          Rails.logger.debug "✅ RFC 7591: Bound app #{existing_app.name} to account=#{selected_account_id}"
        end
        return
      end

      # Lógica original para OAuth dinâmico
      dynamic_app = DynamicOauthService.create_or_find_application_for_account(
        client_id,
        selected_account_id.to_i,
        current_resource_owner,
        redirect_uri
      )

      unless dynamic_app
        render_dynamic_authorization_error
        return
      end

      if Rails.env.development?
        Rails.logger.debug "✅ Dynamic OAuth: Created/found app #{dynamic_app.name} for client_id=#{client_id} in account=#{selected_account_id}"
      end
      return
    end

    # Se não tem account selecionada, verificar se aplicação já existe
    existing_app = OauthApplication.find_by(uid: client_id)
    if existing_app
      # Verificar se é uma aplicação RFC 7591 que precisa de seleção de account
      if existing_app.rfc7591_registered?
        if Rails.env.development?
          Rails.logger.debug "📋 RFC 7591: App #{client_id} registered but needs account selection"
        end
        render_dynamic_authorization_error
        return
      end

      # Aplicação já existe com account vinculada, deixar Doorkeeper processar normalmente
      if Rails.env.development?
        Rails.logger.debug "⏭️ Static OAuth: App #{client_id} already exists, letting Doorkeeper handle"
      end
      return
    end

    # Aplicação não existe - mostrar seleção de accounts disponíveis
    render_dynamic_authorization_error
  end

  def doorkeeper_resource_owner
    @resource_owner ||= current_user
  end

  def current_user
    @current_user ||= begin
      user = nil

      # 1. Warden (Devise)
      if respond_to?(:warden) && warden.authenticated?
        user = warden.user
      end

      # 2. Session
      if user.nil? && session[:current_user_id]
        user = User.find_by(id: session[:current_user_id])
      end

      user
    end
  end

  def bind_rfc7591_app_to_account(application, account_id, current_user)
    # Verificar se o usuário tem acesso admin à account
    account_user = current_user.account_users.find_by(account_id: account_id)
    return false unless account_user&.administrator?

    account = Account.find_by(id: account_id)
    return false unless account

    # Vincular aplicação à account
    application.update!(account_id: account_id)

    if Rails.env.development?
      Rails.logger.debug "🔗 RFC 7591: Bound application #{application.name} (#{application.uid}) to account #{account.name} (#{account_id})"
    end

    true
  rescue => e
    Rails.logger.error "❌ RFC 7591 Binding Error: #{e.message}"
    false
  end

  def is_mcp_application?(application)
    # Check if this is an MCP application by name pattern or specific identifiers
    return false unless application&.name

    mcp_patterns = [
      /mcp/i,
      /model.*context.*protocol/i,
      /inspector/i,
      /claude/i,
      /anthropic/i
    ]

    mcp_patterns.any? { |pattern| application.name.match?(pattern) }
  end

  def auto_bind_mcp_app_to_account(application, user)
    # Find the first account the user has admin access to
    admin_account_user = user.account_users.where(role: 'account_owner').first

    if admin_account_user
      account_id = admin_account_user.account_id

      # Bind the MCP application to this account
      application.update!(account_id: account_id)

      Rails.logger.info "🤖 MCP Auto-bind: Bound #{application.name} to account #{account_id} for user #{user.email}"
      return true
    else
      Rails.logger.warn "⚠️ MCP Auto-bind: User #{user.email} has no admin accounts available"
      return false
    end
  rescue => e
    Rails.logger.error "❌ MCP Auto-bind Error: #{e.message}"
    false
  end

  def render_dynamic_authorization_error
    current_resource_owner = doorkeeper_resource_owner

    # Se for uma requisição AJAX/JSON, retornar dados para o frontend
    if request.xhr? || request.format.json?
      available_accounts = current_resource_owner ? DynamicOauthService.available_accounts_for_user(current_resource_owner) : []

      render json: {
        error: 'account_selection_required',
        error_description: 'Please select an account to authorize this application.',
        available_accounts: available_accounts,
        oauth_params: request.query_parameters
      }, status: :unprocessable_entity
      return
    end

    # Para requisições normais, redirecionar para o frontend
    encoded_oauth_url = CGI.escape(request.url)
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')
    redirect_to "#{frontend_url}/auth?oauth_url=#{encoded_oauth_url}"
  end

  def authorization_request
    @authorization_request ||= begin
      server = Doorkeeper.configuration.authorization_server
      server.authorization_request(authorization_request_params)
    end
  end

  def authorization_request_params
    request.parameters.slice(*Doorkeeper::AuthorizationRequest::ATTRIBUTES)
  end
end
