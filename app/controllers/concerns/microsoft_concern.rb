module MicrosoftConcern
  extend ActiveSupport::Concern

  def microsoft_client
    app_id = GlobalConfigService.load('AZURE_APP_ID', nil)
    app_secret = GlobalConfigService.load('AZURE_APP_SECRET', nil)

    ::OAuth2::Client.new(app_id, app_secret,
                         {
                           site: 'https://login.microsoftonline.com',
                           authorize_url: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
                           token_url: 'https://login.microsoftonline.com/common/oauth2/v2.0/token'
                         })
  end

  # Generates a signed JWT token for Microsoft integration
  #
  # @param account_id [Integer] The account ID to encode in the token
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_microsoft_token(account_id)
    return if client_secret.blank?

    JWT.encode(token_payload(account_id), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Microsoft token: #{e.message}")
    nil
  end

  # Verifies and decodes a Microsoft JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [Integer, nil] The account ID from the token or nil if invalid
  def verify_microsoft_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)
  end

  private

  def token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i
    }
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('AZURE_APP_SECRET', nil)
  end

  def decode_token(token, secret)
    JWT.decode(token, secret, true, {
                 algorithm: 'HS256',
                 verify_expiration: true
               }).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying Microsoft token: #{e.message}")
    nil
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
