class InboxPolicy < ApplicationPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      user.assigned_inboxes
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)

    # For service token authentication, Current.user might be nil
    # In that case, allow access if we have a valid service context
    return true if Current.user.nil? && Current.account.present?

    # Administrators or users with inboxes.read permission can view any inbox
    return true if @account_user&.administrator? || @account_user&.has_permission?('inboxes.read')

    # Regular users can only view assigned inboxes
    Current.user.assigned_inboxes.include? record
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def campaigns?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator? || @account_user.has_permission?('inboxes.create')
  end

  def update?
    @account_user.administrator? || @account_user.has_permission?('inboxes.update')
  end

  def destroy?
    @account_user.administrator? || @account_user.has_permission?('inboxes.delete')
  end

  def set_agent_bot?
    @account_user.administrator? || @account_user.has_permission?('inboxes.update')
  end

  def avatar?
    @account_user.administrator? || @account_user.has_permission?('inboxes.update')
  end

  def setup_channel_provider?
    @account_user.administrator? || @account_user.has_permission?('inboxes.update')
  end

  def disconnect_channel_provider?
    @account_user.administrator? || @account_user.has_permission?('inboxes.update')
  end

  def sync_whatsapp_templates?
    @account_user.administrator? || @account_user.has_permission?('inboxes.sync_whatsapp_templates')
  end

  def whatsapp_templates?
    @account_user.administrator? || @account_user.has_permission?('inboxes.whatsapp_templates')
  end

  def update_whatsapp_template?
    @account_user.administrator? || @account_user.has_permission?('inboxes.update_whatsapp_template')
  end

  def delete_whatsapp_template?
    @account_user.administrator? || @account_user.has_permission?('inboxes.delete_whatsapp_template')
  end

  # Generic message templates (for all channel types)
  def message_templates?
    @account_user.administrator? || @account_user.has_permission?('inboxes.message_templates')
  end

  def update_message_template?
    @account_user.administrator? || @account_user.has_permission?('inboxes.update_message_template')
  end

  def delete_message_template?
    @account_user.administrator? || @account_user.has_permission?('inboxes.delete_message_template')
  end
end
