module OauthAccountHelper
  extend ActiveSupport::Concern
  include Doorkeeper::Rails::Helpers

  private

  def current_account
    @current_account ||= ensure_oauth_account
    Current.account = @current_account
    @current_account
  end

  def ensure_oauth_account
    # Garantir que temos um token OAuth válido
    return render_unauthorized('OAuth token required') unless oauth_token_present?

    # Obter a aplicação OAuth do token
    oauth_application = doorkeeper_token.application
    return render_unauthorized('Invalid OAuth application') unless oauth_application

    # Obter a account vinculada à aplicação OAuth
    account = Account.find(oauth_application.account_id)
    return render_unauthorized('Account not found') unless account
    return render_unauthorized('Account is suspended') unless account.active?

    # Verificar se o usuário tem acesso à account (se for user token)
    if current_user
      account_accessible_for_user?(account)
    elsif @resource.is_a?(AgentBot)
      account_accessible_for_bot?(account)
    end

    account
  end

  def account_accessible_for_user?(account)
    @current_account_user = account.account_users.find_by(user_id: current_user.id)
    Current.account_user = @current_account_user
    return render_unauthorized('You are not authorized to access this account') unless @current_account_user
  end

  def account_accessible_for_bot?(account)
    return render_unauthorized('Bot is not authorized to access this account') unless @resource.agent_bot_inboxes.find_by(account_id: account.id)
  end

  def oauth_token_present?
    request.headers['Authorization']&.start_with?('Bearer ') &&
      request.headers[:api_access_token].blank? &&
      request.headers[:HTTP_API_ACCESS_TOKEN].blank?
  end

  def render_unauthorized(message = 'Unauthorized')
    render json: { error: message }, status: :unauthorized
  end
end
