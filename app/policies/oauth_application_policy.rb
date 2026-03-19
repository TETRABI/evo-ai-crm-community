class OauthApplicationPolicy < ApplicationPolicy
  def index?
    @account_user&.administrator? || @account_user&.has_permission?('oauth_applications.read')
  end

  def show?
    @account_user&.administrator? || @account_user&.has_permission?('oauth_applications.read')
  end

  def create?
    @account_user&.administrator? || @account_user&.has_permission?('oauth_applications.create')
  end

  def update?
    @account_user&.administrator? || @account_user&.has_permission?('oauth_applications.update')
  end

  def destroy?
    @account_user&.administrator? || @account_user&.has_permission?('oauth_applications.delete')
  end

  def regenerate_secret?
    @account_user&.administrator? || @account_user&.has_permission?('oauth_applications.update')
  end
end
