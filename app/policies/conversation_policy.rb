class ConversationPolicy < ApplicationPolicy
  def index?
    # Administrators or users with conversations.read permission can list conversations
    @account_user&.administrator? || @account_user&.has_permission?('conversations.read')
  end

  def show?
    # Administrators or users with conversations.read permission can view conversations
    @account_user&.administrator? || @account_user&.has_permission?('conversations.read')
  end

  def destroy?
    @account_user&.administrator? || @account_user&.has_permission?('conversations.delete')
  end
end
