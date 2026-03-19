# == Schema Information
#
# Table name: account_users
#
#  id                     :uuid             not null, primary key
#  active_at              :datetime
#  auto_offline           :boolean          default(TRUE), not null
#  availability           :integer          default("online"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_custom_role_id :uuid
#  account_id             :uuid             not null
#  inviter_id             :uuid
#  role_id                :uuid
#  user_id                :uuid             not null
#
# Indexes
#
#  index_account_users_on_account_custom_role_id  (account_custom_role_id)
#  index_account_users_on_account_id              (account_id)
#  index_account_users_on_role_id                 (role_id)
#  index_account_users_on_user_id                 (user_id)
#  uniq_user_id_per_account_id                    (account_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_custom_role_id => account_custom_roles.id) ON DELETE => nullify
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inviter_id => users.id)
#  fk_rails_...  (role_id => roles.id)
#  fk_rails_...  (user_id => users.id)
#
class AccountUser < ApplicationRecord
  # Evolution Reference Model - role managed by evo-auth-service
  # This model serves as operational link between users and accounts in Evolution

  include AvailabilityStatusable
  AUTHZ_REMOTE_CACHE_TTL = 30.seconds

  belongs_to :account
  belongs_to :user
  belongs_to :inviter, class_name: 'User', optional: true

  enum availability: { online: 0, offline: 1, busy: 2 }

  accepts_nested_attributes_for :account

  after_create_commit :notify_creation, :create_notification_setting
  after_destroy :notify_deletion, :remove_user_from_account
  after_save :update_presence_in_redis, if: :saved_change_to_availability?

  validates :user_id, uniqueness: { scope: :account_id }

  def create_notification_setting
    setting = user.notification_settings.new(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_assignment]
    setting.selected_push_flags = [:push_conversation_assignment]
    setting.save!
  end

  def remove_user_from_account
    ::Agents::DestroyJob.perform_later(account, user)
  end

  # Delegate role and permission queries to evo-auth-service
  def role
    @role ||= evo_auth_role&.dig('key') || 'agent'
  end

  def administrator?
    role == 'account_owner'
  end

  def agent?
    role == 'agent' || !administrator?
  end

  # Check if user has a specific permission in this account
  def has_permission?(permission_key)
    return false unless permission_key.present?

    cache_key = "account:#{user_id}:#{account_id}:#{permission_key}"
    if Current.evo_permission_cache&.key?(cache_key)
      return Current.evo_permission_cache[cache_key]
    end

    store_key = "evo_auth:account_permission:user=#{user_id}:account=#{account_id}:permission=#{permission_key}"
    result = Rails.cache.fetch(store_key, expires_in: AUTHZ_REMOTE_CACHE_TTL) do
      # Use EvoAuthService to check permission
      evo_auth_service = EvoAuthService.new
      evo_auth_service.check_account_permission(user_id, account_id, permission_key)
    end

    Current.evo_permission_cache ||= {}
    Current.evo_permission_cache[cache_key] = result
    result
  rescue StandardError => e
    Rails.logger.error "AccountUser#has_permission?: Error checking permission #{permission_key}: #{e.message}"
    false
  end

  def push_event_data
    {
      id: id,
      availability: availability,
      role: role,
      user_id: user_id
    }
  end

  private

  def evo_auth_role
    @evo_auth_role ||= EvoAuthService.new.get_role(user_id, account_id)
  end

  def notify_creation
    Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account)
  end

  def notify_deletion
    Rails.configuration.dispatcher.dispatch(AGENT_REMOVED, Time.zone.now, account: account)
  end

  def update_presence_in_redis
    OnlineStatusTracker.set_status(account.id, user.id, availability)
  end
end

AccountUser.prepend_mod_with('AccountUser')
AccountUser.include_mod_with('Concerns::AccountUser')
