class Integrations::App
  include Linear::IntegrationHelper
  include Hubspot::IntegrationHelper
  attr_accessor :params

  def initialize(params)
    @params = params
  end

  def id
    params[:id]
  end

  def name
    I18n.t("integration_apps.#{params[:i18n_key]}.name")
  end

  def description
    I18n.t("integration_apps.#{params[:i18n_key]}.description")
  end

  def short_description
    I18n.t("integration_apps.#{params[:i18n_key]}.short_description")
  end

  def logo
    params[:logo]
  end

  def fields
    params[:fields]
  end

  # There is no way to get the account_id from OAuth callbacks
  # so we are using token generation to encode account_id in the state parameter
  def encode_state
    case params[:id]
    when 'linear'
      generate_linear_token(Current.account.id)
    when 'hubspot'
      generate_hubspot_token(Current.account.id)
    else
      nil
    end
  end

  def action
    case params[:id]
    when 'slack'
      client_id = GlobalConfigService.load('SLACK_CLIENT_ID', nil)
      "#{params[:action]}&client_id=#{client_id}&redirect_uri=#{self.class.slack_integration_url}"
    when 'linear'
      build_linear_action
    when 'hubspot'
      build_hubspot_action
    else
      params[:action]
    end
  end

  def active?(account)
    case params[:id]
    when 'slack'
      GlobalConfigService.load('SLACK_CLIENT_SECRET', nil).present?
    when 'linear'
      GlobalConfigService.load('LINEAR_CLIENT_ID', nil).present?
    when 'hubspot'
      account.feature_enabled?('hubspot_integration') && GlobalConfigService.load('HUBSPOT_CLIENT_ID', nil).present?
    when 'shopify'
      account.feature_enabled?('shopify_integration') && GlobalConfigService.load('SHOPIFY_CLIENT_ID', nil).present?
    when 'leadsquared'
      account.feature_enabled?('crm_integration')
    when 'bms'
      account.feature_enabled?('bms_integration')
    when 'webhook', 'dashboard_apps', 'openai'
      true # Estas integrações devem sempre aparecer para configuração
    when 'oauth_applications'
      false
    else
      false # Disabled by default for unknown integrations
    end
  end

  def build_linear_action
    app_id = GlobalConfigService.load('LINEAR_CLIENT_ID', nil)
    [
      "#{params[:action]}?response_type=code",
      "client_id=#{app_id}",
      "redirect_uri=#{self.class.linear_integration_url}",
      "state=#{encode_state}",
      'scope=read,write',
      'prompt=consent'
    ].join('&')
  end

  def build_hubspot_action
    app_id = GlobalConfigService.load('HUBSPOT_CLIENT_ID', nil)
    [
      "#{params[:action]}?response_type=code",
      "client_id=#{app_id}",
      "redirect_uri=#{self.class.hubspot_integration_url}",
      "state=#{encode_state}",
      'scope=crm.objects.contacts.read crm.objects.contacts.write crm.objects.deals.read crm.objects.deals.write crm.objects.companies.read crm.objects.companies.write crm.objects.line_items.read crm.objects.owners.read crm.schemas.deals.read oauth settings.users.read'
    ].join('&')
  end

  def enabled?(account)
    case params[:id]
    when 'webhook'
      account.webhooks.exists?
    when 'dashboard_apps'
      account.dashboard_apps.exists?
    when 'oauth_applications'
      account.oauth_applications.exists?
    else
      account.hooks.exists?(app_id: id)
    end
  end

  def hooks
    Current.account.hooks.where(app_id: id)
  end

  def self.slack_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/settings/integrations/slack"
  end

  def self.linear_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/linear/callback"
  end

  def self.hubspot_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/hubspot/callback"
  end

  class << self
    def apps
      Hashie::Mash.new(APPS_CONFIG)
    end

    def all
      apps.values.each_with_object([]) do |app, result|
        result << new(app)
      end
    end

    def find(params)
      all.detect { |app| app.id == params[:id] }
    end
  end
end
