module UserAttributeHelpers
  extend ActiveSupport::Concern

  def available_name
    self[:display_name].presence || name
  end

  def availability_status
    availability.presence || 'offline'
  end

  def auto_offline
    false
  end

  def inviter
    nil
  end

  def administrator?
    type == 'SuperAdmin'
  end

  def agent?
    !administrator?
  end

  def role
    administrator? ? 'administrator' : 'agent'
  end

  # In single-tenant mode there is no AccountUser / permission table.
  # All authenticated users are considered to have every permission.
  def has_permission?(_permission)
    true
  end

  # Used internally for Evolution in Evolution
  def hmac_identifier
    hmac_key = GlobalConfig.get('EVOLUTION_INBOX_HMAC_KEY')['EVOLUTION_INBOX_HMAC_KEY']
    return OpenSSL::HMAC.hexdigest('sha256', hmac_key, email) if hmac_key.present?

    ''
  end
end
