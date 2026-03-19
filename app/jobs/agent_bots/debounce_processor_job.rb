class AgentBots::DebounceProcessorJob < ApplicationJob
  queue_as :default

  def perform(agent_bot_id, conversation_id, job_id_param = nil)
    Rails.logger.info '[AgentBot DebounceProcessor] === JOB STARTED ==='
    Rails.logger.info "[AgentBot DebounceProcessor] Agent Bot ID: #{agent_bot_id}"
    Rails.logger.info "[AgentBot DebounceProcessor] Conversation ID: #{conversation_id}"
    Rails.logger.info "[AgentBot DebounceProcessor] Job ID param: #{job_id_param.inspect}"
    Rails.logger.info "[AgentBot DebounceProcessor] Self job_id: #{job_id}"

    agent_bot = AgentBot.find(agent_bot_id)
    conversation = Conversation.find(conversation_id)

    # Verifica se este job ainda é válido (não foi cancelado)
    debounce_service = AgentBots::DebounceService.new(agent_bot, conversation)
    job_key = "agent_bot_debounce_job:#{agent_bot_id}:#{conversation_id}"

    # Verifica se o cache store é NullStore (não persiste dados)
    cache_store_is_null = Rails.cache.class.name.include?('NullStore')
    cache_store_is_file = Rails.cache.class.name.include?('FileStore')

    # Se o cache é NullStore, processa mesmo sem validação
    if cache_store_is_null
      Rails.logger.warn "[AgentBot DebounceProcessor] NullStore detected - skipping job_id validation, processing anyway (dev/test mode)"
    else
      current_job_id = Rails.cache.read(job_key)

      # With FileStore in multi-pod Kubernetes, the job_id may be written on one pod
      # (where EventDispatcher runs) but this job executes on a different pod with
      # its own empty FileStore. When cache is empty (nil), skip validation instead
      # of treating it as "cancelled", since we can't distinguish a cache miss from
      # an actual cancellation.
      if current_job_id.nil? && cache_store_is_file
        Rails.logger.info "[AgentBot DebounceProcessor] FileStore cache miss (cross-pod) - skipping job_id validation, processing anyway"
      elsif current_job_id.present? && current_job_id != job_id
        Rails.logger.info '[AgentBot DebounceProcessor] ⚠️  Job was cancelled or superseded by newer message'
        Rails.logger.info "[AgentBot DebounceProcessor] Current job in cache: #{current_job_id}, This job: #{job_id}"
        return
      end
    end

    Rails.logger.info "[AgentBot DebounceProcessor] Processing debounce timeout for conversation #{conversation_id}"

    # Log conversation state BEFORE reload
    Rails.logger.info "[AgentBot DebounceProcessor] BEFORE reload - Status: #{conversation.status}, Inbox ID: #{conversation.inbox_id}"

    # Reload conversation with associations to get latest status and agent_bot_inbox
    conversation.reload

    # Log conversation state AFTER reload
    Rails.logger.info "[AgentBot DebounceProcessor] AFTER reload - Status: #{conversation.status}, Inbox ID: #{conversation.inbox_id}"

    inbox = conversation.inbox
    inbox.reload if inbox.present?

    # Explicitly load agent_bot_inbox association
    agent_bot_inbox = inbox&.agent_bot_inbox

    Rails.logger.info "[AgentBot DebounceProcessor] Current conversation status: #{conversation.status}"
    Rails.logger.info "[AgentBot DebounceProcessor] Conversation inbox_id: #{conversation.inbox_id}"
    Rails.logger.info "[AgentBot DebounceProcessor] Inbox present?: #{inbox.present?}"
    Rails.logger.info "[AgentBot DebounceProcessor] Agent bot inbox present?: #{agent_bot_inbox.present?}"
    Rails.logger.info "[AgentBot DebounceProcessor] Agent bot inbox active?: #{agent_bot_inbox&.active?}"
    Rails.logger.info "[AgentBot DebounceProcessor] Agent bot inbox ID: #{agent_bot_inbox&.id}"
    Rails.logger.info "[AgentBot DebounceProcessor] Agent bot ID: #{agent_bot_inbox&.agent_bot_id}"

    # IMPORTANT: Check if the agent_bot passed to this job is actually assigned to this conversation's inbox
    # This ensures we're processing with the correct bot even if inbox_id changed
    agent_bot_inbox_for_conversation = inbox&.agent_bot_inbox
    agent_bot_matches = agent_bot_inbox_for_conversation&.agent_bot_id == agent_bot.id
    Rails.logger.info "[AgentBot DebounceProcessor] Agent bot #{agent_bot.id} matches conversation inbox agent_bot (#{agent_bot_inbox_for_conversation&.agent_bot_id})?: #{agent_bot_matches}"

    # Also check if inbox has any active bot (fallback check)
    inbox_has_active_bot = inbox&.active_bot?
    Rails.logger.info "[AgentBot DebounceProcessor] Inbox has any active bot?: #{inbox_has_active_bot}"

    # If the agent_bot matches and conversation is not resolved, process it
    # This ensures bot responses even if status changed to 'open' or inbox_id changed
    if agent_bot_matches && !conversation.resolved?
      Rails.logger.info "[AgentBot DebounceProcessor] ✅ Agent bot matches conversation inbox and conversation is not resolved - processing anyway"
    elsif !conversation_eligible_for_bot_reply?(conversation)
      Rails.logger.warn "[AgentBot DebounceProcessor] ⚠️  Conversation #{conversation_id} no longer eligible (status: #{conversation.status})"
      Rails.logger.warn "[AgentBot DebounceProcessor] Allowed statuses: #{conversation.inbox.agent_bot_inbox&.allowed_conversation_statuses || ['pending']}"

      # Limpa o cache mesmo assim
      debounce_service.clear_cache

      Rails.logger.warn '[AgentBot DebounceProcessor] ⚠️  Skipping processing and cleared cache'
      return
    end

    Rails.logger.info '[AgentBot DebounceProcessor] ✅ Conversation eligible, processing cached messages'

    # Processa as mensagens em cache
    debounce_service.process_cached_messages

    Rails.logger.info '[AgentBot DebounceProcessor] ✅ Debounce processing completed'

  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[AgentBot DebounceProcessor] Record not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[AgentBot DebounceProcessor] Error processing debounce: #{e.message}"
    Rails.logger.error "[AgentBot DebounceProcessor] Backtrace: #{e.backtrace.first(5).join("\n")}"

    # Em caso de erro, limpa o cache para evitar mensagens presas
    begin
      agent_bot = AgentBot.find(agent_bot_id)
      conversation = Conversation.find(conversation_id)
      debounce_service = AgentBots::DebounceService.new(agent_bot, conversation)
      debounce_service.clear_cache
      Rails.logger.info '[AgentBot DebounceProcessor] Cache cleared due to error'
    rescue StandardError => cleanup_error
      Rails.logger.error "[AgentBot DebounceProcessor] Failed to clear cache: #{cleanup_error.message}"
    end

    raise e
  end

  private

  def conversation_eligible_for_bot_reply?(conversation)
    # Reload inbox to ensure we have latest data
    inbox = conversation.inbox
    inbox.reload if inbox.present?

    # Explicitly load agent_bot_inbox
    agent_bot_inbox = inbox&.agent_bot_inbox

    Rails.logger.info "[AgentBot DebounceProcessor] Checking eligibility - Status: #{conversation.status}, AgentBotInbox present?: #{agent_bot_inbox.present?}"

    # Se não houver configuração, usa comportamento padrão (apenas pending)
    if agent_bot_inbox.blank?
      is_pending = conversation.status == 'pending'
      Rails.logger.info "[AgentBot DebounceProcessor] No AgentBotInbox config, using default (pending only): #{is_pending}"
      return is_pending
    end

    # Usa a configuração do AgentBotInbox para verificar se o status é permitido
    eligible = agent_bot_inbox.should_process_conversation?(conversation)
    Rails.logger.info "[AgentBot DebounceProcessor] Conversation status: #{conversation.status}, Allowed statuses: #{agent_bot_inbox.allowed_conversation_statuses.inspect}, Eligible: #{eligible}"
    eligible
  end
end
