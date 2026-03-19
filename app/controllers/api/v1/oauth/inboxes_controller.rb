# Herda diretamente do controller de accounts
class Api::V1::Oauth::InboxesController < Api::V1::Accounts::InboxesController
  # Remove os middlewares do controller pai que dependem de account_id na URL
  skip_before_action :current_account
  skip_before_action :authenticate_request!

  # Aplica middleware OAuth
  include Doorkeeper::Rails::Helpers
  include OauthAccountHelper
  before_action :ensure_oauth_authentication!
  before_action :current_account

  private

  def ensure_oauth_authentication!
    unless oauth_token_present?
      render_unauthorized('OAuth token required. This endpoint only accepts OAuth authentication.')
      return
    end

    # Verificar se o token é válido antes de chamar doorkeeper
    token = Doorkeeper::AccessToken.by_token(doorkeeper_token_value)
    unless token&.accessible?
      render_unauthorized('Invalid or expired OAuth token')
      return
    end

    # Verificar se tem escopo adequado
    unless token.acceptable?(['admin']) || token.acceptable?(['read']) || token.acceptable?(['inboxes:read'])
      render_unauthorized('Insufficient scope for this endpoint')
      return
    end

    # Token válido, continuar com autenticação
    @resource = User.find(token.resource_owner_id) if token.resource_owner_id
    Current.user = @resource if @resource
  end

  def doorkeeper_token_value
    request.headers['Authorization']&.gsub(/^Bearer\s+/, '')
  end

  # Simula o params[:account_id] que o controller pai espera
  def params
    super.merge(account_id: extract_account_id_from_token)
  end

  # Extrai account_id diretamente do token OAuth (sem recursão)
  def extract_account_id_from_token
    @extracted_account_id ||= begin
      return nil unless oauth_token_present?
      oauth_application = doorkeeper_token&.application
      oauth_application&.account_id
    end
  end
end
