# Herda diretamente do controller de accounts
class Api::V1::Oauth::PipelineStagesController < Api::V1::Accounts::PipelineStagesController
  # Remove os middlewares do controller pai que dependem de account_id na URL
  skip_before_action :current_account
  skip_before_action :authenticate_request!

  # Remove os before_actions específicos do controller pai que dependem de Current.account

  require_permissions({
    index: 'oauth_pipeline_stages.read',
    show: 'oauth_pipeline_stages.read',
    create: 'oauth_pipeline_stages.create',
    update: 'oauth_pipeline_stages.update',
    destroy: 'oauth_pipeline_stages.delete'
  })
  skip_before_action :fetch_pipeline
  
  skip_before_action :fetch_pipeline_stage

  # Aplica middleware OAuth
  include Doorkeeper::Rails::Helpers
  include OauthAccountHelper
  before_action :ensure_oauth_authentication!
  before_action :current_account
  before_action :fetch_pipeline
  before_action :fetch_pipeline_stage, only: [:show, :update, :destroy, :move_up, :move_down]

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
    unless token.acceptable?(['admin']) || token.acceptable?(['read']) || token.acceptable?(['pipelines:read'])
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

  # OAuth-aware version of parent controller methods
  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:pipeline_id])
    authorize @pipeline, :view?
  end

  def fetch_pipeline_stage
    @pipeline_stage = @pipeline.pipeline_stages.find(params[:id])
  end

end
