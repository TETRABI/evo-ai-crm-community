# == Schema Information
#
# Table name: labels
#
#  id              :uuid             not null, primary key
#  color           :string           default("#1f93ff"), not null
#  description     :text
#  show_on_sidebar :boolean
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :uuid
#
# Indexes
#
#  index_labels_on_account_id            (account_id)
#  index_labels_on_title_and_account_id  (title,account_id) UNIQUE
#
class Label < ApplicationRecord
  include RegexHelper
  include AccountCacheRevalidator
  include Events::Types

  belongs_to :account

  validates :title,
            presence: { message: I18n.t('errors.validations.presence') },
            format: { with: UNICODE_CHARACTER_NUMBER_SPACE_HYPHEN_UNDERSCORE, allow_blank: true },
            uniqueness: { scope: :account_id }

  after_create_commit :dispatch_create_event
  after_update_commit :update_associated_models, :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event
  default_scope { order(:title) }

  before_validation do
    next unless attribute_present?('title')
    
    if title.is_a?(String)
      stripped = title.strip
      self.title = stripped.present? ? stripped.downcase : nil
    end
  end

  def conversations
    account.conversations.tagged_with(title)
  end

  def messages
    account.messages.where(conversation_id: conversations.pluck(:id))
  end

  def reporting_events
    account.reporting_events.where(conversation_id: conversations.pluck(:id))
  end

  private

  def update_associated_models
    return unless title_previously_changed?

    Labels::UpdateJob.perform_later(title, title_previously_was, account_id)
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(LABEL_CREATED, Time.zone.now, label: self, account: account)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(LABEL_UPDATED, Time.zone.now, label: self, account: account, saved_changes: saved_changes)
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(LABEL_DELETED, Time.zone.now, label: self, account: account)
  end
end
