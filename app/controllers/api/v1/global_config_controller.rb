# frozen_string_literal: true

class Api::V1::GlobalConfigController < Api::BaseController
  # Public, read-only config: expose only non-sensitive keys used by frontend SDKs/feature gating
  skip_before_action :authenticate_request!

  def show
    render json: public_config
  end

  private

  def public_config
    {
      fbAppId: GlobalConfigService.load('FB_APP_ID', ''),
      fbApiVersion: GlobalConfigService.load('FACEBOOK_API_VERSION', 'v17.0'),
      wpAppId: GlobalConfigService.load('WP_APP_ID', ''),
      wpApiVersion: GlobalConfigService.load('WP_API_VERSION', 'v23.0'),
      wpWhatsappConfigId: GlobalConfigService.load('WP_WHATSAPP_CONFIG_ID', ''),
      instagramAppId: GlobalConfigService.load('INSTAGRAM_APP_ID', nil),
      googleOAuthClientId: GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil),
      azureAppId: GlobalConfigService.load('AZURE_APP_ID', nil),
      # 🔒 SECURITY: Don't expose sensitive API URLs to frontend
      # Frontend only needs to know IF config exists, not the actual values
      hasEvolutionConfig: evolution_configured?,
      hasEvolutionGoConfig: evolution_go_configured?,
      openaiConfigured: openai_configured?,
      enableAccountSignup: enable_account_signup?,
      recaptchaSiteKey: GlobalConfigService.load('RECAPTCHA_SITE_KEY', nil),
      clarityProjectId: GlobalConfigService.load('CLARITY_PROJECT_ID', nil),
      whitelabel: whitelabel_config
    }
  end

  def whitelabel_config
    enabled = whitelabel_enabled?

    return { enabled: false } unless enabled

    {
      enabled: true,
      logo: {
        light: GlobalConfigService.load('WHITELABEL_LOGO_LIGHT', '/brand-assets/logo.svg'),
        dark: GlobalConfigService.load('WHITELABEL_LOGO_DARK', '/brand-assets/logo_dark.svg')
      },
      favicon: GlobalConfigService.load('WHITELABEL_FAVICON', nil),
      companyName: GlobalConfigService.load('WHITELABEL_COMPANY_NAME', nil),
      systemName: GlobalConfigService.load('WHITELABEL_SYSTEM_NAME', nil),
      termsOfServiceUrl: GlobalConfigService.load('WHITELABEL_TERMS_OF_SERVICE_URL', nil),
      privacyPolicyUrl: GlobalConfigService.load('WHITELABEL_PRIVACY_POLICY_URL', nil),
      colors: {
        light: {
          primary: GlobalConfigService.load('WHITELABEL_PRIMARY_COLOR_LIGHT', '#00d4aa'),
          primaryForeground: GlobalConfigService.load('WHITELABEL_PRIMARY_FOREGROUND_LIGHT', '#ffffff')
        },
        dark: {
          primary: GlobalConfigService.load('WHITELABEL_PRIMARY_COLOR_DARK', '#00ffcc'),
          primaryForeground: GlobalConfigService.load('WHITELABEL_PRIMARY_FOREGROUND_DARK', '#000000')
        }
      }
    }
  end

  def whitelabel_enabled?
    value = GlobalConfigService.load('WHITELABEL_ENABLED', 'false')
    normalized_value = value.to_s.strip.downcase
    normalized_value == 'true'
  end

  def enable_account_signup?
    value = GlobalConfigService.load('ENABLE_ACCOUNT_SIGNUP', 'false')
    normalized_value = value.to_s.strip.downcase
    normalized_value == 'true'
  end

  def openai_configured?
    api_url = GlobalConfigService.load('OPENAI_API_URL', '').to_s.strip
    api_key = GlobalConfigService.load('OPENAI_API_SECRET', '').to_s.strip
    model = GlobalConfigService.load('OPENAI_MODEL', '').to_s.strip

    api_url.present? && api_key.present? && model.present?
  end

  def evolution_configured?
    api_url = GlobalConfigService.load('EVOLUTION_API_URL', '').to_s.strip
    admin_token = GlobalConfigService.load('EVOLUTION_ADMIN_SECRET', '').to_s.strip

    api_url.present? && admin_token.present?
  end

  def evolution_go_configured?
    api_url = GlobalConfigService.load('EVOLUTION_GO_API_URL', '').to_s.strip
    admin_token = GlobalConfigService.load('EVOLUTION_GO_ADMIN_SECRET', '').to_s.strip

    api_url.present? && admin_token.present?
  end
end
