require 'digest'
require 'base64'
require 'json'

module EvoAuthConcern
  extend ActiveSupport::Concern

  AUTH_VALIDATE_CACHE_TTL = 20.seconds

  private

  def authenticate_user_with_evo_auth(token, token_type)
    Current.evo_auth_validation_cache ||= {}
    cache_key = evo_auth_validation_cache_key(token, token_type)
    user_data = Current.evo_auth_validation_cache[cache_key]

    auth_service = EvoAuthService.new
    unless user_data
      store_key = evo_auth_validation_store_key(cache_key)
      user_data = Rails.cache.read(store_key)

      unless user_data
        user_data = auth_service.validate_token(token: token, token_type: token_type)
        ttl = auth_validation_cache_ttl(token, token_type)
        Rails.cache.write(store_key, user_data, expires_in: ttl) if ttl.positive?
      end
    end

    Current.evo_auth_validation_cache[cache_key] = user_data
    
    set_current_user_from_auth_data(user_data, token, token_type)
    true
  rescue EvoAuthService::ValidationError => e
    Rails.logger.warn "EvoAuth: Token validation failed: #{e.message}"
    error_code = e.code.presence || ApiErrorCodes::UNAUTHORIZED
    error_status = e.status.presence || :unauthorized
    error_response(error_code, e.message, status: error_status)
    false
  rescue EvoAuthService::AuthenticationError => e
    Rails.logger.error "EvoAuth: Authentication service error: #{e.message}"
    error_response(ApiErrorCodes::SERVICE_UNAVAILABLE, 'Authentication service unavailable', status: :service_unavailable)
    false
  end

  def bearer_token_present?
    request.headers['Authorization']&.start_with?('Bearer ')
  end

  def set_current_user_from_auth_data(user_data, token, token_type)
    user = find_local_user(user_data['user'])
    raise EvoAuthService::ValidationError, 'User not found locally' unless user

    # Set current user
    Current.user = user
    @current_user = user
    Current.authentication_method = token_type

    # Store tokens for downstream services
    if token_type == 'bearer'
      Current.bearer_token = token
    elsif token_type == 'api_access_token'
      Current.api_access_token = token
    end

    # Set account context - pass token_data and token_type to allow token_account_id extraction
    set_account_context(user, user_data['accounts'], user_data, token_type)
  end

  def set_account_context(user, accounts_data, token_data = {}, token_type = nil)
    # When using api_access_token, the token may be linked to a specific account
    # In that case, use that account automatically without requiring account-id header
    token_account_id = token_data['token_account_id'] || token_data[:token_account_id]
    is_api_access_token = (token_type || Current.authentication_method) == 'api_access_token'
    
    account_id = Account.first&.id

    return unless account_id

    account = Account.find_by(id: account_id)
    
    if account && user_has_access_to_account?(user, account)
      Current.account = account
      Current.account_user = user.account_users.find_by(account: account)
      source = if is_api_access_token && token_account_id.present?
        'api_access_token token'
      elsif request.headers['account-id']
        'account-id header'
      elsif params[:account_id]
        'params'
      else
        'accounts_data fallback'
      end
      Rails.logger.debug "EvoAuth: Set account context from #{source} for user=#{user.id} account=#{account.id}"
    else
      Rails.logger.warn "EvoAuth: User #{user.id} does not have access to account #{account_id}"
    end
  end

  def find_local_user(user_data)
    return nil unless user_data

    User.find_by(email: user_data['email']) || User.find_by(id: user_data['id'])
  end

  def user_has_access_to_account?(user, account)
    user.account_users.exists?(account: account)
  end

  # Override current_user method to return our authenticated user
  def current_user
    @current_user || Current.user
  end

  def evo_auth_validation_cache_key(token, token_type)
    "#{token_type}:#{Digest::SHA256.hexdigest(token.to_s)}"
  end

  def evo_auth_validation_store_key(cache_key)
    "evo_auth:validate:#{cache_key}"
  end

  def auth_validation_cache_ttl(token, token_type)
    ttl = AUTH_VALIDATE_CACHE_TTL
    return ttl unless token_type.to_s == 'bearer'

    payload = decode_jwt_payload(token)
    return ttl unless payload.is_a?(Hash) && payload['exp'].present?

    remaining = payload['exp'].to_i - Time.now.to_i
    return 0.seconds if remaining <= 0

    [ttl, remaining.seconds].min
  rescue StandardError
    ttl
  end

  def decode_jwt_payload(token)
    segments = token.to_s.split('.')
    return {} if segments.length < 2

    payload_segment = segments[1]
    padding = '=' * ((4 - payload_segment.length % 4) % 4)
    decoded = Base64.urlsafe_decode64("#{payload_segment}#{padding}")
    JSON.parse(decoded)
  rescue StandardError
    {}
  end
end
