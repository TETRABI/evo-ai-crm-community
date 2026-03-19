class PipelineTaskPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    return true if @account_user.administrator?

    # Agents can see tasks from their account
    @record.account_id == @account_user.account_id
  end

  def create?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    return true if @account_user.administrator?

    # Creator or assignee can update
    @record.created_by_id == @user.id || @record.assigned_to_id == @user.id
  end

  def destroy?
    return true if @account_user.administrator?

    # Only creator can delete
    @record.created_by_id == @user.id
  end

  def complete?
    update?
  end

  def cancel?
    update?
  end

  def reopen?
    update?
  end

  def add_subtask?
    # Can add subtask if can create tasks and can update parent task
    create? && update?
  end

  def move?
    # Can move if can update the task
    update?
  end

  def reorder?
    # Can reorder if can update the task
    update?
  end

  def statistics?
    index?
  end
end
