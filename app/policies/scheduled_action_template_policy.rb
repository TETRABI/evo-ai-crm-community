# frozen_string_literal: true

class ScheduledActionTemplatePolicy < ApplicationPolicy
  def index?
    user.account_users.exists?(account_id: record.account_id)
  end

  def show?
    user.account_users.exists?(account_id: record.account_id)
  end

  def create?
    user.account_users.exists?(account_id: record.account_id)
  end

  def update?
    record.created_by == user.id || user_admin?
  end

  def destroy?
    record.created_by == user.id || user_admin?
  end

  def apply?
    user.account_users.exists?(account_id: record.account_id)
  end

  private

  def user_admin?
    user.account_users.find_by(account_id: record.account_id)&.role == 'admin'
  end
end
