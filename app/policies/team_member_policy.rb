class TeamMemberPolicy < ApplicationPolicy
  def index?
    # Administrators or users with team_members.read permission can list team members
    @account_user&.administrator? || @account_user&.has_permission?('team_members.read')
  end

  def show?
    # Administrators or users with team_members.read permission can view team members
    @account_user&.administrator? || @account_user&.has_permission?('team_members.read')
  end

  def create?
    @account_user&.administrator? || @account_user&.has_permission?('team_members.create')
  end

  def destroy?
    @account_user&.administrator? || @account_user&.has_permission?('team_members.delete')
  end

  def update?
    @account_user&.administrator? || @account_user&.has_permission?('team_members.update')
  end
end
