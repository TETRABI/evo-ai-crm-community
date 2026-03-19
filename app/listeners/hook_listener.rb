class HookListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]

    execute_hooks(event, message)
  end

  def message_updated(event)
    message = extract_message_and_account(event)[0]

    execute_hooks(event, message)
  end

  def contact_created(event)
    contact = extract_contact_and_account(event)[0]
    execute_account_hooks(event, contact.account, contact: contact)
  end

  def contact_updated(event)
    contact = extract_contact_and_account(event)[0]
    execute_account_hooks(event, contact.account, contact: contact, changed_attributes: event.data[:changed_attributes])
  end

  def conversation_created(event)
    conversation = extract_conversation_and_account(event)[0]
    execute_account_hooks(event, conversation.account, conversation: conversation)
  end

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    # Only trigger for status changes is resolved
    return unless conversation.status == 'resolved'

    execute_account_hooks(event, conversation.account, conversation: conversation)
  end

  def label_created(event)
    label = event.data[:label]
    account = event.data[:account]
    execute_account_hooks(event, account, label: label)
  end

  def label_updated(event)
    label = event.data[:label]
    account = event.data[:account]
    execute_account_hooks(event, account, label: label, saved_changes: event.data[:saved_changes])
  end

  def label_deleted(event)
    label = event.data[:label]
    account = event.data[:account]
    execute_account_hooks(event, account, label: label)
  end

  def custom_attribute_definition_created(event)
    custom_attribute_definition = event.data[:custom_attribute_definition]
    account = event.data[:account]
    execute_account_hooks(event, account, custom_attribute_definition: custom_attribute_definition)
  end

  def custom_attribute_definition_updated(event)
    custom_attribute_definition = event.data[:custom_attribute_definition]
    account = event.data[:account]
    execute_account_hooks(event, account, custom_attribute_definition: custom_attribute_definition, saved_changes: event.data[:saved_changes])
  end

  def custom_attribute_definition_deleted(event)
    custom_attribute_definition = event.data[:custom_attribute_definition]
    account = event.data[:account]
    execute_account_hooks(event, account, custom_attribute_definition: custom_attribute_definition)
  end

  private

  def execute_hooks(event, message)
    message.account.hooks.each do |hook|
      next if hook.inbox.present? && hook.inbox != message.inbox

      HookJob.perform_later(hook, event.name, message: message)
    end
  end

  def execute_account_hooks(event, account, event_data = {})
    account.hooks.account_hooks.find_each do |hook|
      HookJob.perform_later(hook, event.name, event_data)
    end
  end
end
