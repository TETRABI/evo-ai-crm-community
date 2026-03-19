# frozen_string_literal: true

module Api::V1::ResourceLimitsHelper
  def validate_agent_bot_limit
    limits = Current.account.usage_limits[:agent_bots]
    return if limit_is_unlimited?(limits[:allowed])
    return unless limits[:consumed] >= limits[:allowed]

    render_payment_required('Agent Bot limit exceeded. Upgrade to a higher plan')
  end

  def validate_pipeline_limit
    limits = Current.account.usage_limits[:pipelines]
    return if limit_is_unlimited?(limits[:allowed])
    return unless limits[:consumed] >= limits[:allowed]

    render_payment_required('Pipeline limit exceeded. Upgrade to a higher plan')
  end

  def validate_automation_limit
    limits = Current.account.usage_limits[:automations]
    return if limit_is_unlimited?(limits[:allowed])
    return unless limits[:consumed] >= limits[:allowed]

    render_payment_required('Automation limit exceeded. Upgrade to a higher plan')
  end

  def validate_team_limit
    limits = Current.account.usage_limits[:teams]
    return if limit_is_unlimited?(limits[:allowed])
    return unless limits[:consumed] >= limits[:allowed]

    render_payment_required('Team limit exceeded. Upgrade to a higher plan')
  end

  def validate_channel_limit(channel_type)
    channel_key = case channel_type
                  when 'Channel::Whatsapp' then 'whatsapp'
                  when 'Channel::Email' then 'email'
                  when 'Channel::WebWidget' then 'web_widget'
                  when 'Channel::Api' then 'api'
                  when 'Channel::TwilioSms' then 'twilio_sms'
                  when 'Channel::Telegram' then 'telegram'
                  when 'Channel::Instagram' then 'instagram'
                  when 'Channel::FacebookPage' then 'facebook_page'
                  else
                    return # Unknown channel type, skip validation
                  end

    limits = Current.account.usage_limits[:channels][channel_key]
    return if limit_is_unlimited?(limits[:allowed])
    return unless limits[:consumed] >= limits[:allowed]

    channel_name = channel_type.demodulize.humanize
    render_payment_required("#{channel_name} channel limit exceeded. Upgrade to a higher plan")
  end

  def validate_custom_attribute_limit(attribute_model)
    model_key = attribute_model.gsub('_attribute', '').to_sym
    custom_attributes_limits = Current.account.usage_limits[:custom_attributes]
    
    # Return early if custom_attributes limits is nil or doesn't have the model_key
    return unless custom_attributes_limits&.key?(model_key)
    
    limits = custom_attributes_limits[model_key]
    return if limit_is_unlimited?(limits[:allowed])
    return unless limits[:consumed] >= limits[:allowed]

    model_name = model_key.to_s.humanize
    render_payment_required("#{model_name} custom attribute limit exceeded. Upgrade to a higher plan")
  end

  def validate_channel_limit_for_creation
    return unless permitted_params.dig(:channel, :type)

    channel_type = "Channel::#{permitted_params.dig(:channel, :type).classify}"
    validate_channel_limit(channel_type)
  end

  private

  def limit_is_unlimited?(limit_value)
    # Se o limite for 0, é considerado ilimitado
    # Se o limite for igual ao EvolutionApp.max_limit, também é considerado ilimitado
    limit_value == 0 || limit_value >= EvolutionApp.max_limit.to_i
  end
end
