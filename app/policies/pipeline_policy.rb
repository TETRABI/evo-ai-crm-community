class PipelinePolicy < ApplicationPolicy
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
      # Return all pipelines accessible to the user in the current account
      scope.where(account_id: @account.id)
    end
  end

  def index?
    # Administrators or users with pipelines.read permission can list pipelines
    @account_user&.administrator? || @account_user&.has_permission?('pipelines.read')
  end

  def show?
    # Administrators or users with pipelines.read permission can view pipelines
    @account_user&.administrator? || @account_user&.has_permission?('pipelines.read')
  end

  def view?
    # Alias for show? - used by some controllers
    show?
  end

  def create?
    # Administrators or users with pipelines.create permission can create pipelines
    @account_user&.administrator? || @account_user&.has_permission?('pipelines.create')
  end

  def update?
    # Administrators or users with pipelines.update permission can update pipelines
    @account_user&.administrator? || @account_user&.has_permission?('pipelines.update')
  end

  def destroy?
    # Administrators or users with pipelines.delete permission can delete pipelines
    @account_user&.administrator? || @account_user&.has_permission?('pipelines.delete')
  end

  def archive?
    # Administrators or users with pipelines.update permission can archive pipelines
    @account_user&.administrator? || @account_user&.has_permission?('pipelines.update')
  end

  def stats?
    # Administrators or users with pipelines.read permission can view pipeline statistics
    @account_user&.administrator? || @account_user&.has_permission?('pipelines.read')
  end
end
