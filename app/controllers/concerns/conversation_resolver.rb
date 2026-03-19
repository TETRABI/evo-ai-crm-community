# frozen_string_literal: true

# ConversationResolver - Support for both display_id and UUID conversation identification
module ConversationResolver
  extend ActiveSupport::Concern

  private

  # UUID pattern for conversation identification
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def resolve_conversation(conversation_param)
    return nil if conversation_param.blank?

    if uuid_format?(conversation_param)
      find_conversation_by_uuid(conversation_param)
    else
      find_conversation_by_display_id(conversation_param)
    end
  end

  def uuid_format?(param)
    param.to_s.match?(UUID_PATTERN)
  end

  def find_conversation_by_uuid(uuid)
    Current.account.conversations.find_by(id: uuid) ||
      Current.account.conversations.find_by(uuid: uuid)
  end

  def find_conversation_by_display_id(display_id)
    Current.account.conversations.find_by(display_id: display_id)
  end
end