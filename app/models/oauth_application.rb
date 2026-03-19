# == Schema Information
#
# Table name: oauth_applications
#
#  id           :uuid             not null, primary key
#  confidential :boolean          default(TRUE), not null
#  name         :string           not null
#  redirect_uri :text             not null
#  scopes       :string           default(""), not null
#  secret       :string           not null
#  trusted      :boolean          default(FALSE), not null
#  uid          :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :uuid
#
# Indexes
#
#  index_oauth_applications_on_account_id  (account_id)
#  index_oauth_applications_on_uid         (uid) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class OauthApplication < Doorkeeper::Application
  belongs_to :account, optional: true

  validates :account_id, presence: true, unless: :rfc7591_registered?
  validates :trusted, inclusion: { in: [true, false] }

  scope :for_account, ->(account) { where(account: account) }
  scope :dynamic_apps, -> { where('name LIKE ?', 'Dynamic OAuth -%') }
  scope :static_apps, -> { where.not('name LIKE ?', 'Dynamic OAuth -%') }
  scope :rfc7591_apps, -> { where(account_id: nil) }

  def display_secret
    if trusted?
      secret
    else
      secret[0..7] + ('*' * (secret.length - 8))
    end
  end

  def dynamic_oauth_app?
    DynamicOauthService.is_dynamic_client_id?(uid)
  end

  def static_oauth_app?
    !dynamic_oauth_app?
  end

  def self.find_or_create_dynamic_for_account(account_id, user, redirect_uri = nil)
    DynamicOauthService.create_or_find_dynamic_application(
      DynamicOauthService.generate_dynamic_client_id(account_id),
      user,
      redirect_uri
    )
  end

  # Verifica se a aplicação foi registrada via RFC 7591 (sem account vinculada)
  def rfc7591_registered?
    account_id.nil?
  end

  # Verifica se precisa de seleção de account durante autorização
  def requires_account_selection?
    rfc7591_registered?
  end
end
