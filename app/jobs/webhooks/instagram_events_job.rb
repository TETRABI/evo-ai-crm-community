class Webhooks::InstagramEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  # @return [Array] We will support further events like reaction or seen in future
  SUPPORTED_EVENTS = [:message, :read].freeze

  def perform(entries)
    @entries = entries

    sender_id_value = sender_id || 'unknown'
    ig_account_id_value = ig_account_id || 'unknown'

    Rails.logger.info("Instagram Events Job: Starting processing - sender_id: #{sender_id_value}, ig_account_id: #{ig_account_id_value}")

    key = format(::Redis::Alfred::IG_MESSAGE_MUTEX, sender_id: sender_id_value, ig_account_id: ig_account_id_value)
    Rails.logger.info("Instagram Events Job: Using lock key: #{key}")

    with_lock(key) do
      process_entries(entries)
    end
  end

  # https://developers.facebook.com/docs/messenger-platform/instagram/features/webhook
  def process_entries(entries)
    entries.each do |entry|
      process_single_entry(entry.with_indifferent_access)
    end
  end

  private

  def process_single_entry(entry)
    if test_event?(entry)
      process_test_event(entry)
      return
    end

    process_messages(entry)
  end

  def process_messages(entry)
    messaging_array = messages(entry)
    Rails.logger.info("Instagram Events Job: Processing #{messaging_array.length} messaging entries from entry: #{entry[:id]}")

    messaging_array.each_with_index do |messaging, index|
      messaging_indifferent = messaging.with_indifferent_access
      Rails.logger.info("Instagram Events Job Messaging[#{index}]: #{messaging_indifferent.inspect}")
      Rails.logger.info("Instagram Events Job Messaging[#{index}] keys: #{messaging_indifferent.keys.inspect}")

      # Track whether this messaging was resolved from a message_edit event.
      # The page_id route is ONLY valid for message_edit-resolved events (real incoming DMs).
      # Plain message events via the page_id route are echoes or outgoing reflections — must be skipped.
      resolved_from_edit = false

      # Instagram Graph API changed behavior: new DMs now arrive as `message_edit` with `num_edit: 0`
      # instead of a regular `message` event. We resolve these by fetching the full message via API.
      # See: https://developers.facebook.com/docs/messenger-platform/instagram/features/webhook
      if new_message_via_edit?(messaging_indifferent)
        Rails.logger.info("Instagram Events Job: Detected message_edit with num_edit=0 (new message), resolving via Graph API")
        ig_account_id_for_channel = entry[:id]
        resolved = resolve_message_edit_to_messaging(messaging_indifferent, ig_account_id_for_channel)
        if resolved.nil?
          Rails.logger.warn("Instagram Events Job: Could not resolve message_edit to messaging, skipping")
          next
        end
        messaging_indifferent = resolved
        resolved_from_edit = true
      elsif unsupported_event?(messaging_indifferent)
        # Skip real edits (num_edit > 0), reactions, postbacks, etc.
        Rails.logger.info("Instagram Events Job: Skipping unsupported event type: #{messaging_indifferent.keys.inspect}")
        next
      end

      # Log sender/recipient info for debugging
      Rails.logger.info("Instagram Events Job Messaging[#{index}] sender: #{messaging_indifferent[:sender].inspect}")
      Rails.logger.info("Instagram Events Job Messaging[#{index}] recipient: #{messaging_indifferent[:recipient].inspect}")
      Rails.logger.info("Instagram Events Job Messaging[#{index}] message: #{messaging_indifferent[:message].inspect}")

      instagram_id = instagram_id(messaging_indifferent, entry)
      Rails.logger.info("Instagram Events Job Messaging[#{index}] resolved instagram_id: #{instagram_id.inspect}")

      unless instagram_id.present?
        Rails.logger.warn("Instagram Events Job: Could not determine instagram_id from messaging: #{messaging_indifferent.inspect}, entry: #{entry[:id]}")
        next
      end

      channel = find_channel(instagram_id)
      Rails.logger.info("Instagram Events Job Messaging[#{index}] found channel: #{channel.inspect}")

      if channel.blank?
        Rails.logger.warn("Instagram Events Job: Channel not found for instagram_id: #{instagram_id}")
        next
      end

      Rails.logger.info("Instagram Events Job: Found channel #{channel.id} (#{channel.class.name}) for instagram_id: #{instagram_id}")

      # The page_id route is used exclusively for DMs that arrive as message_edit (num_edit:0).
      # Any plain `message` event arriving via entry.id == page_id is either:
      #   - an echo (is_echo: true) of an outgoing agent message, or
      #   - a reflection of an outgoing CRM response (no is_echo, different sender PSID).
      # Both create spurious contacts/conversations and must be skipped.
      # Only events resolved from message_edit (resolved_from_edit=true) are allowed through.
      if channel.is_a?(Channel::Instagram) &&
         channel.page_id.present? &&
         entry[:id].to_s == channel.page_id.to_s &&
         !resolved_from_edit
        Rails.logger.info("Instagram Events Job: Skipping message via page_id route (entry.id=#{entry[:id]}, resolved_from_edit=false) — echo or outgoing reflection")
        next
      end

      event_name_result = event_name(messaging_indifferent)
      Rails.logger.info("Instagram Events Job Messaging[#{index}] event_name result: #{event_name_result.inspect}")

      if event_name_result
        Rails.logger.info("Instagram Events Job: Processing event: #{event_name_result}")
        begin
          send(event_name_result, messaging_indifferent, channel)
          Rails.logger.info("Instagram Events Job: Successfully processed event: #{event_name_result}")
        rescue StandardError => e
          Rails.logger.error("Instagram Events Job: Error processing event #{event_name_result}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          raise
        end
      else
        Rails.logger.warn("Instagram Events Job: No supported event found in messaging: #{messaging_indifferent.keys.inspect}")
        Rails.logger.warn("Instagram Events Job: Supported events are: #{SUPPORTED_EVENTS.inspect}")
      end
    end
  end

  def agent_message_via_echo?(messaging)
    messaging[:message].present? && messaging[:message][:is_echo].present?
  end

  # Returns true when Instagram delivers a NEW message disguised as a message_edit event.
  # This happens when `num_edit == 0`, meaning it's the original (unedited) version of the message.
  # The Instagram Graph API changed behavior so that new DMs arrive as message_edit with num_edit: 0.
  def new_message_via_edit?(messaging)
    return false unless messaging.is_a?(Hash)

    edit = messaging.with_indifferent_access[:message_edit]
    edit.is_a?(Hash) && edit[:num_edit].to_i == 0
  end

  # Fetches the full message content from the Instagram Graph API using the `mid` from a
  # `message_edit` event. Returns a normalized messaging hash (same shape as a regular `message`
  # event) that can be processed by the existing pipeline, or nil on failure.
  def resolve_message_edit_to_messaging(messaging, ig_account_id)
    mid = messaging.dig(:message_edit, :mid)
    unless mid.present?
      Rails.logger.warn("Instagram Events Job: message_edit has no mid, cannot resolve")
      return nil
    end

    # Find the channel to get the access_token
    channel = find_channel(ig_account_id)
    unless channel.present?
      Rails.logger.warn("Instagram Events Job: No channel found for ig_account_id #{ig_account_id}, cannot resolve message_edit")
      return nil
    end

    access_token = channel.access_token
    api_version = GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v23.0')
    fields = 'id,message,from,to,attachments'
    url = "https://graph.instagram.com/#{api_version}/#{mid}?fields=#{fields}&access_token=#{access_token}"

    Rails.logger.info("Instagram Events Job: Fetching message #{mid} from Graph API (token filtered)")
    response = HTTParty.get(url)

    unless response.success?
      Rails.logger.error("Instagram Events Job: Graph API returned #{response.code} for mid #{mid}: #{response.body}")
      return build_placeholder_messaging(messaging, mid, ig_account_id)
    end

    data = JSON.parse(response.body).with_indifferent_access

    if data[:error].present?
      Rails.logger.error("Instagram Events Job: Graph API error for mid #{mid}: #{data[:error].inspect}")
      return build_placeholder_messaging(messaging, mid, ig_account_id)
    end

    Rails.logger.info("Instagram Events Job: Resolved message_edit mid #{mid} → #{data.slice(:id, :message, :from, :to).inspect}")

    # Build a synthetic messaging hash that mirrors a regular `message` event payload.
    # `from` is the sender (the user who sent the DM), `to.data[0]` is the recipient (the IG account).
    sender_id = data.dig(:from, :id)
    recipient_id = data.dig(:to, :data, 0, :id) || ig_account_id

    unless sender_id.present?
      Rails.logger.warn("Instagram Events Job: Could not determine sender from Graph API response: #{data.inspect}")
      return build_placeholder_messaging(messaging, mid, ig_account_id)
    end

    {
      sender:    { id: sender_id },
      recipient: { id: recipient_id },
      timestamp: data[:timestamp] || messaging[:timestamp],
      message: {
        mid:         data[:id] || mid,
        text:        data[:message],
        attachments: data[:attachments]
      }.compact
    }.with_indifferent_access
  end

  # Builds a fallback messaging hash when the Graph API is unavailable or lacks permission
  # to read the full message content (requires instagram_business_manage_messages Advanced Access).
  # Creates a placeholder DM notification so agents know a message arrived even without the content.
  # The sender uses a per-channel placeholder ID so all "unknown" DMs for the same inbox are grouped.
  def build_placeholder_messaging(messaging, mid, ig_account_id)
    Rails.logger.info("Instagram Events Job: Building placeholder messaging for mid #{mid} — API unavailable, Advanced Access may be required")
    {
      sender:    { id: "ig_dm_pending_#{ig_account_id}" },
      recipient: { id: ig_account_id },
      timestamp: messaging[:timestamp],
      message: {
        mid:  mid,
        text: '📩 Nova mensagem do Instagram recebida. O conteúdo não está disponível temporariamente — acesse o DM direto no Instagram para visualizar.'
      }
    }.with_indifferent_access
  end

  def unsupported_event?(messaging)
    # Check if this is an unsupported event type (like message_edit, reaction, etc.)
    # message_edit with num_edit == 0 is handled separately via new_message_via_edit? (new DM behavior).
    # message_edit with num_edit > 0 is a real edit and falls through to this skip.
    return false unless messaging.is_a?(Hash)

    messaging_indifferent = messaging.with_indifferent_access
    unsupported_keys = [:message_edit, :reaction, :postback, :account_linking]
    unsupported_keys.any? { |key| messaging_indifferent.key?(key) }
  end

  def test_event?(entry)
    entry[:changes].present?
  end

  def process_test_event(entry)
    messaging = extract_messaging_from_test_event(entry)

    Instagram::TestEventService.new(messaging).perform if messaging.present?
  end

  def extract_messaging_from_test_event(entry)
    entry[:changes].first&.dig(:value) if entry[:changes].present?
  end

  def instagram_id(messaging, entry = nil)
    Rails.logger.info("Instagram Events Job: Resolving instagram_id - messaging keys: #{messaging.keys.inspect}")

    if agent_message_via_echo?(messaging)
      sender_id = messaging.dig(:sender, :id)
      Rails.logger.info("Instagram Events Job: Echo message, using sender_id: #{sender_id}")
      return sender_id if sender_id.present?
    else
      recipient_id = messaging.dig(:recipient, :id)
      Rails.logger.info("Instagram Events Job: Normal message, using recipient_id: #{recipient_id}")
      return recipient_id if recipient_id.present?
    end

    if entry.present?
      entry_id = entry[:id]
      Rails.logger.info("Instagram Events Job: Using fallback entry[:id]: #{entry_id}")
      return entry_id if entry_id.present?
    end

    fallback_id = ig_account_id
    Rails.logger.info("Instagram Events Job: Using last resort ig_account_id: #{fallback_id}")
    fallback_id
  end

  def ig_account_id
    @entries&.first&.dig(:id)
  end

  def sender_id
    @entries&.each do |entry|
      messaging_array = entry[:messaging] || entry[:standby] || []
      messaging_array.each do |messaging|
        next if unsupported_event?(messaging.with_indifferent_access)

        if messaging[:sender]&.dig(:id).present?
          return messaging[:sender][:id]
        end

        if messaging[:recipient]&.dig(:id).present?
          return messaging[:recipient][:id]
        end
      end
    end

    ig_account_id
  end

  def find_channel(instagram_id)
    Rails.logger.info("Instagram Events Job: Searching for Channel::Instagram with instagram_id: #{instagram_id}")
    channel = Channel::Instagram.find_by(instagram_id: instagram_id)

    if channel.blank?
      Rails.logger.info("Instagram Events Job: Searching for Channel::FacebookPage with instagram_id: #{instagram_id}")
      channel = Channel::FacebookPage.find_by(instagram_id: instagram_id)
    end

    # Instagram delivers incoming DMs through the linked Facebook Page ID (page_id),
    # while echoes and subscriptions use the Instagram account ID (instagram_id).
    # Both identifiers refer to the same channel — fall back to page_id lookup.
    if channel.blank?
      Rails.logger.info("Instagram Events Job: Searching for Channel::Instagram with page_id: #{instagram_id}")
      channel = Channel::Instagram.find_by(page_id: instagram_id)
    end

    if channel.present?
      Rails.logger.info("Instagram Events Job: Found channel #{channel.id} (#{channel.class.name}) with instagram_id: #{instagram_id}")
    else
      Rails.logger.warn("Instagram Events Job: No channel found for instagram_id: #{instagram_id}")
    end

    channel
  end

  def event_name(messaging)
    SUPPORTED_EVENTS.find { |key| messaging.key?(key) }
  end

  def message(messaging, channel)
    if channel.is_a?(Channel::Instagram)
      ::Instagram::MessageText.new(messaging, channel).perform
    else
      ::Instagram::Messenger::MessageText.new(messaging, channel).perform
    end
  end

  def read(messaging, channel)
    ::Instagram::ReadStatusService.new(params: messaging, channel: channel).perform
  end

  def messages(entry)
    (entry[:messaging].presence || entry[:standby] || [])
  end
end
