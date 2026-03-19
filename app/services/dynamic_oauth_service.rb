# frozen_string_literal: true

class DynamicOauthService
  DYNAMIC_CLIENT_PREFIX = 'dynamic_account_'.freeze

  def self.generate_dynamic_client_id(account_id)
    "#{DYNAMIC_CLIENT_PREFIX}#{account_id}"
  end

  def self.is_dynamic_client_id?(client_id)
    client_id&.start_with?(DYNAMIC_CLIENT_PREFIX)
  end

  def self.extract_account_id(client_id)
    return nil unless is_dynamic_client_id?(client_id)

    client_id.gsub(DYNAMIC_CLIENT_PREFIX, '').to_i
  end

  def self.create_or_find_dynamic_application(client_id, current_user, redirect_uri = nil)
    return nil unless is_dynamic_client_id?(client_id)

    account_id = extract_account_id(client_id)
    return nil unless account_id

    # Verificar se o usuário tem acesso admin à account
    account_user = current_user.account_users.find_by(account_id: account_id)
    return nil unless account_user&.administrator?

    account = Account.find_by(id: account_id)
    return nil unless account

    # Procurar por aplicação dinâmica existente pelo UID (client_id)
    application = Doorkeeper::Application.find_by(uid: client_id)

    # Se existe, verificar se pertence à account correta
    if application && application.account_id != account.id
      # Aplicação existe mas pertence a outra account - não pode usar
      return nil
    end

    # Se não existe, criar nova aplicação
    app_name = "Dynamic OAuth - #{account.name}"

    unless application
      application = Doorkeeper::Application.create!(
        name: app_name,
        account_id: account.id,
        uid: client_id,  # Usar o client_id original (ex: dynamic_account_1)
        secret: generate_secret,
        redirect_uri: redirect_uri || 'urn:ietf:wg:oauth:2.0:oob',
        scopes: 'admin',
        trusted: false,
        confidential: false  # Para PKCE, aplicação pública
      )
    end

    # Atualizar redirect_uri se fornecido e diferente
    if redirect_uri && application.redirect_uri != redirect_uri
      application.update!(redirect_uri: redirect_uri)
    end

    application
  end

  def self.create_or_find_application_for_account(client_id, account_id, current_user, redirect_uri = nil)
    # Verificar se o usuário tem acesso admin à account
    account_user = current_user.account_users.find_by(account_id: account_id)
    return nil unless account_user&.administrator?

    account = Account.find_by(id: account_id)
    return nil unless account

    # Procurar por aplicação existente pelo UID (client_id)
    application = Doorkeeper::Application.find_by(uid: client_id)

    # Se existe, verificar se pertence à account correta
    if application && application.account_id != account.id
      # Aplicação existe mas pertence a outra account - não pode usar
      return nil
    end

    # Se aplicação existe, garantir que é pública (para PKCE)
    if application && application.confidential?
      application.update!(confidential: false)
    end

    # Se não existe, criar nova aplicação
    app_name = "OAuth App - #{account.name}"

    unless application
      application = Doorkeeper::Application.create!(
        name: app_name,
        account_id: account.id,
        uid: client_id,  # Usar o client_id original (ex: cliente_teste)
        secret: generate_secret,
        redirect_uri: redirect_uri || 'urn:ietf:wg:oauth:2.0:oob',
        scopes: 'admin',
        trusted: false
      )
    end

    # Atualizar redirect_uri se fornecido e diferente
    if redirect_uri && application.redirect_uri != redirect_uri
      application.update!(redirect_uri: redirect_uri)
    end

    application
  end

  def self.find_application_by_client_id(client_id)
    if is_dynamic_client_id?(client_id)
      # Para client_ids dinâmicos, usar o UID personalizado
      Doorkeeper::Application.find_by(uid: client_id)
    else
      # Para client_ids normais, usar a busca padrão do Doorkeeper
      Doorkeeper::Application.find_by(uid: client_id)
    end
  end

  def self.available_accounts_for_user(user)
    return [] unless user

    user.account_users
        .joins(:account)
        .where(role: 'account_owner')
        .includes(:account)
        .map do |account_user|
      {
        account_id: account_user.account.id,
        account_name: account_user.account.name,
        dynamic_client_id: generate_dynamic_client_id(account_user.account.id)
      }
    end
  end

  private

  def self.generate_secret
    SecureRandom.hex(32)
  end
end
