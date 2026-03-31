class AgentBots::DebounceService
  CACHE_PREFIX = 'agent_bot_debounce'.freeze
  JOB_KEY_PREFIX = 'agent_bot_debounce_job'.freeze

  def initialize(agent_bot, conversation)
    @agent_bot = agent_bot
    @conversation = conversation
    @cache_key = "#{CACHE_PREFIX}:#{@agent_bot.id}:#{@conversation.id}"
    @job_key = "#{JOB_KEY_PREFIX}:#{@agent_bot.id}:#{@conversation.id}"
  end

  def add_message(message)
      Rails.logger.info "[AgentBot Debounce] === Adding message to cache ==="
    Rails.logger.info "[AgentBot Debounce] Conversation ID: #{@conversation.id}"
    Rails.logger.info "[AgentBot Debounce] Message ID: #{message.id}"
    Rails.logger.info "[AgentBot Debounce] Message content: #{message.content[0..100]}"

    # Recupera mensagens existentes ou cria nova lista
    cached_messages = cached_messages_from_cache
    cached_messages << {
      content: message.content,
      created_at: message.created_at.to_i,
      message_id: message.id
    }

    # Salva no cache com TTL de 1 hora (segurança)
    Rails.cache.write(@cache_key, cached_messages, expires_in: 1.hour)

    Rails.logger.info "[AgentBot Debounce] Messages in cache: #{cached_messages.length}"

    # Agenda/reagenda o processamento
    schedule_processing
  end

  def cached_messages_from_cache
    # Se o cache store é NullStore, retorna array vazio (mensagens não podem ser persistidas)
    if Rails.cache.class.name.include?('NullStore')
      Rails.logger.warn "[AgentBot Debounce] NullStore detected - cache cannot persist messages"
      return []
    end
    Rails.cache.fetch(@cache_key, expires_in: 1.hour) { [] }
  end

  def clear_cache
    Rails.logger.info "[AgentBot Debounce] Clearing cache for conversation #{@conversation.id}"
    Rails.cache.delete(@cache_key)
    Rails.cache.delete(@job_key)
  end

  def process_cached_messages
    Rails.logger.info "[AgentBot Debounce] Processing cached messages for conversation #{@conversation.id}"
    Rails.logger.info "[AgentBot Debounce] Cache store: #{Rails.cache.class.name}"

    cached_messages = cached_messages_from_cache

    if cached_messages.empty?
      # Se o cache é NullStore, tenta buscar mensagens recentes diretamente do banco
      if Rails.cache.class.name.include?('NullStore')
        Rails.logger.warn "[AgentBot Debounce] NullStore detected - fetching recent messages from database"
        # Usa um intervalo maior para garantir que capturamos todas as mensagens
        # que foram adicionadas durante o período de debounce, mesmo que o job execute um pouco depois
        # Usa o maior entre (debounce_time * 3) ou 10 segundos para garantir que não perdemos mensagens
        calculated_interval = (@agent_bot.debounce_time * 3)
        min_interval_seconds = [calculated_interval, 10].max
        time_threshold = min_interval_seconds.seconds.ago
        Rails.logger.info "[AgentBot Debounce] Searching for messages created after: #{time_threshold} (interval: #{min_interval_seconds}s)"

        recent_messages = @conversation.messages
          .where(message_type: :incoming)
          .where('created_at > ?', time_threshold)
          .order(created_at: :asc)

        Rails.logger.info "[AgentBot Debounce] Found #{recent_messages.count} messages in database (threshold: #{time_threshold})"

        if recent_messages.any?
          cached_messages = recent_messages.map do |msg|
            {
              content: msg.content,
              created_at: msg.created_at.to_i,
              message_id: msg.id
            }
          end
          Rails.logger.info "[AgentBot Debounce] Processing #{cached_messages.length} messages from database"
        else
          Rails.logger.warn '[AgentBot Debounce] No recent messages found in database - cannot process bot response'
          return
        end
      else
        Rails.logger.info '[AgentBot Debounce] No cached messages found'
        return
      end
    end

    # Junta todas as mensagens com quebra de linha dupla
    combined_content = cached_messages.pluck(:content).join("\n\n")

    Rails.logger.info "[AgentBot Debounce] Combined #{cached_messages.length} messages into single request"
    Rails.logger.info "[AgentBot Debounce] Combined content preview: #{combined_content[0..200]}#{'...' if combined_content.length > 200}"

    # Limpa o cache
    clear_cache

    # Cria uma mensagem virtual para processar
    virtual_message = Message.new(
      content: combined_content,
      conversation: @conversation,
      inbox: @conversation.inbox,
      message_type: :incoming,
      created_at: Time.current
    )

    # Processa através do serviço apropriado dependendo do tipo de agente
    virtual_payload = build_virtual_payload(virtual_message)

    if @agent_bot.evo_ai_provider?
      # Para EVO AI, usa o HttpRequestService
      http_service = AgentBots::HttpRequestService.new(@agent_bot, virtual_payload)
      http_service.perform
    elsif @agent_bot.n8n_provider?
      # Para N8n, usa o N8nRequestService
      n8n_service = AgentBots::N8nRequestService.new(@agent_bot, virtual_payload)
      n8n_service.perform
    else
      # Para outros tipos, usa o WebhookJob
      AgentBots::WebhookJob.perform_later(@agent_bot.outgoing_url, virtual_payload)
    end
  end

  private

  def build_virtual_payload(virtual_message)
    {
      event: 'message_created',
      id: virtual_message.id,
      content: virtual_message.content,
      message_type: virtual_message.message_type,
      created_at: virtual_message.created_at.to_i,
      conversation: {
        id: @conversation.id,
        display_id: @conversation.display_id
      },
      conversation_id: @conversation.id,
      account: {
        id: nil,
        name: GlobalConfigService.load('BRAND_NAME', 'Evo CRM')
      },
      inbox: {
        id: @conversation.inbox.id,
        name: @conversation.inbox.name
      },
      sender: {
        id: virtual_message.sender&.id,
        name: virtual_message.sender&.name,
        type: virtual_message.sender_type
      },
      contact: {
        id: @conversation.contact.id,
        name: @conversation.contact.name
      }
    }
  end

  def schedule_processing
    Rails.logger.info "[AgentBot Debounce] === Scheduling processing ==="
    Rails.logger.info "[AgentBot Debounce] Agent Bot ID: #{@agent_bot.id}"
    Rails.logger.info "[AgentBot Debounce] Conversation ID: #{@conversation.id}"
    Rails.logger.info "[AgentBot Debounce] Debounce time: #{@agent_bot.debounce_time}s"

    # Cancela job anterior se existir
    cancel_existing_job

    # Agenda novo job
    scheduled_job = AgentBots::DebounceProcessorJob.set(wait: @agent_bot.debounce_time.seconds)
                                                   .perform_later(@agent_bot.id, @conversation.id, nil)

    # Salva o job_id no cache APÓS agendar o job
    # O job_id está disponível imediatamente após perform_later
    job_id = scheduled_job.job_id

    # Se o cache é NullStore, não tenta salvar (mas continua funcionando)
    unless Rails.cache.class.name.include?('NullStore')
      Rails.cache.write(@job_key, job_id, expires_in: 1.hour)
      Rails.logger.info "[AgentBot Debounce] Saved job_id to cache: #{job_id}"
    else
      Rails.logger.warn "[AgentBot Debounce] NullStore detected - job_id not saved to cache, but job will process anyway"
    end

    Rails.logger.info "[AgentBot Debounce] Scheduled job: job_id=#{job_id.inspect}, provider_job_id=#{scheduled_job.provider_job_id.inspect}"
    Rails.logger.info "[AgentBot Debounce] ✅ Scheduled job for processing in #{@agent_bot.debounce_time}s"
    Rails.logger.info "[AgentBot Debounce] Job key: #{@job_key}"
  end

  def cancel_existing_job
    # Tenta cancelar job anterior se existir no cache
    previous_job_id = Rails.cache.read(@job_key)
    return unless previous_job_id

    Rails.logger.info "[AgentBot Debounce] Previous job_id exists in cache: #{previous_job_id}"
    Rails.logger.info "[AgentBot Debounce] New job will override, old job will be ignored when it executes"
  end
end
