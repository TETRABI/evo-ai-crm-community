# frozen_string_literal: true

# Concern para verificação de permissões usando evo-auth-service
# Este concern é usado nos controllers APÓS a autenticação
module EvoPermissionConcern
  extend ActiveSupport::Concern
  AUTHZ_REMOTE_CACHE_TTL = 30.seconds

  class_methods do
    # Define múltiplas permissões de uma vez
    def require_permissions(mapping, type: :account)
      mapping.each do |action, permission_key|
        define_method("check_#{action}_permission!") do
          check_permission!(permission_key, type)
        end

        before_action "check_#{action}_permission!".to_sym, only: [action]
      end
    end

    # Define permissão para uma action específica
    def require_permission(action, permission_key, type: :account)
      define_method("check_#{action}_permission!") do
        check_permission!(permission_key, type)
      end

      before_action "check_#{action}_permission!".to_sym, only: [action]
    end
  end

  private

  # Método principal de verificação de permissão
  def check_permission!(permission_key, type)
    # Se autenticado via service token, permitir acesso (service tokens têm privilégios elevados)
    if Current.service_authenticated == true
      Rails.logger.info "EvoPermission: Service token authenticated - granting access to #{permission_key}"
      return
    end

    # Extrair IDs do contexto atual
    user_id = Current.user&.id
    account_id = Current.account&.id

    # Verificar permissão baseado no tipo
    has_permission = if type == :account
                      unless account_id
                        Rails.logger.error "EvoPermission: Missing account_id for account-scoped permission"
                         render_permission_denied
                        return
                      end
                      has_account_permission?(user_id, account_id, permission_key)
                    else
                      unless user_id
                        Rails.logger.error "EvoPermission: Missing user_id"
                        render_permission_denied
                        return
                      end
                      has_user_permission?(user_id, permission_key)
                    end

    unless has_permission
      Rails.logger.warn "EvoPermission: Access denied - user #{user_id} lacks #{permission_key}"
      render_permission_denied
    end
  end

  # Verificar permissão específica de account (para rotas /api/v1/accounts/:account_id/*)
  def has_account_permission?(user_id, account_id, permission)
    Current.evo_permission_cache ||= {}
    cache_key = "account:#{user_id}:#{account_id}:#{permission}"
    return Current.evo_permission_cache[cache_key] if Current.evo_permission_cache.key?(cache_key)

    store_key = "evo_auth:account_permission:user=#{user_id}:account=#{account_id}:permission=#{permission}"
    has_perm = Rails.cache.fetch(store_key, expires_in: AUTHZ_REMOTE_CACHE_TTL) do
      evo_auth_service = EvoAuthService.new
      evo_auth_service.check_account_permission(user_id, account_id, permission)
    end

    Current.evo_permission_cache[cache_key] = has_perm

    has_perm
  end

  # Verificar permissão global de usuário (para outras rotas)
  def has_user_permission?(user_id, permission)
    Current.evo_permission_cache ||= {}
    cache_key = "user:#{user_id}:#{permission}"
    return Current.evo_permission_cache[cache_key] if Current.evo_permission_cache.key?(cache_key)

    evo_auth_service = EvoAuthService.new
    has_perm = evo_auth_service.check_user_permission(user_id, permission)
    Current.evo_permission_cache[cache_key] = has_perm

    has_perm
  rescue StandardError => e
    Rails.logger.error "Error checking permission #{permission} for user #{user_id}: #{e.message}"

    # Em caso de erro, negar acesso por segurança
    false
  end

  def render_permission_denied
    render json: {
      error: 'Forbidden - Insufficient permissions',
      message: 'You do not have the required permissions to access this resource'
    }, status: :forbidden
  end

  # Helper method para verificar permissão específica
  def can_perform_action?(resource, action, user_id = nil, account_id = nil)
    user_id ||= Current.user&.id
    account_id ||= Current.account&.id

    return false unless user_id && account_id

    permission = "#{resource}.#{action}"
    has_evo_permission?(user_id, account_id, permission)
  end
end
