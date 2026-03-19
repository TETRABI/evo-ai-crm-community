require_relative '../../lib/mail/resend_provider'
require_relative '../../lib/mail/bms_provider'

Rails.application.configure do
  #########################################
  # Configuration Related to Action Mailer
  #########################################

  # We need the application frontend url to be used in our emails
  config.action_mailer.default_url_options = { host: ENV['FRONTEND_URL'] } if ENV['FRONTEND_URL'].present?
  # We load certain mailer templates from our database. This ensures changes to it is reflected immediately
  config.action_mailer.perform_caching = false
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # Config related to smtp
  smtp_settings = {
    address: ENV.fetch('SMTP_ADDRESS', 'localhost'),
    port: ENV.fetch('SMTP_PORT', 587)
  }

  smtp_settings[:authentication] = ENV.fetch('SMTP_AUTHENTICATION', 'login').to_sym if ENV['SMTP_AUTHENTICATION'].present?
  smtp_settings[:domain] = ENV['SMTP_DOMAIN'] if ENV['SMTP_DOMAIN'].present?
  smtp_settings[:user_name] = ENV.fetch('SMTP_USERNAME', nil)
  smtp_settings[:password] = ENV.fetch('SMTP_PASSWORD', nil)
  smtp_settings[:enable_starttls_auto] = ActiveModel::Type::Boolean.new.cast(ENV.fetch('SMTP_ENABLE_STARTTLS_AUTO', true))
  smtp_settings[:openssl_verify_mode] = ENV['SMTP_OPENSSL_VERIFY_MODE'] if ENV['SMTP_OPENSSL_VERIFY_MODE'].present?
  smtp_settings[:ssl] = ActiveModel::Type::Boolean.new.cast(ENV.fetch('SMTP_SSL', true)) if ENV['SMTP_SSL']
  smtp_settings[:tls] = ActiveModel::Type::Boolean.new.cast(ENV.fetch('SMTP_TLS', true)) if ENV['SMTP_TLS']
  smtp_settings[:open_timeout] = ENV['SMTP_OPEN_TIMEOUT'].to_i if ENV['SMTP_OPEN_TIMEOUT'].present?
  smtp_settings[:read_timeout] = ENV['SMTP_READ_TIMEOUT'].to_i if ENV['SMTP_READ_TIMEOUT'].present?

  # Configure SMTP as base settings (will be overridden by higher priority providers)
  config.action_mailer.delivery_method = :smtp unless Rails.env.test?
  config.action_mailer.smtp_settings = smtp_settings

  # Use sendmail if using postfix for email
  config.action_mailer.delivery_method = :sendmail if ENV['SMTP_ADDRESS'].blank?

  # You can use letter opener for your local development by setting the environment variable
  config.action_mailer.delivery_method = :letter_opener if Rails.env.development? && ENV['LETTER_OPENER']

  # Register email providers
  ActionMailer::Base.add_delivery_method :bms, Mail::BmsProvider
  ActionMailer::Base.add_delivery_method :resend, Mail::ResendProvider

  # Configure delivery method based on available providers after Rails initialization
  Rails.application.configure do
    config.after_initialize do
      begin
        # Load configurations from GlobalConfig (database) - highest priority
        bms_api_key = GlobalConfigService.load('BMS_API_KEY', nil) if defined?(GlobalConfigService)
        resend_api_key = GlobalConfigService.load('RESEND_API_KEY', nil) if defined?(GlobalConfigService)
        resend_api_key ||= ENV['RESEND_API_KEY']  # Fallback to ENV

        if bms_api_key.present?
          ActionMailer::Base.delivery_method = :bms
          Rails.logger.info "📧 MAILER CONFIG: BMS email provider configured as primary delivery method"
        elsif resend_api_key.present?
          ActionMailer::Base.delivery_method = :resend
          Rails.logger.info "📧 MAILER CONFIG: Resend email provider configured as delivery method"
        else
          Rails.logger.info "📧 MAILER CONFIG: Using SMTP/Sendmail delivery method (no BMS/Resend configured)"
        end
      rescue => e
        Rails.logger.warn "📧 MAILER CONFIG: Error loading email provider configs: #{e.message}, using SMTP"
      end
    end
  end

  #########################################
  # Configuration Related to Action MailBox
  #########################################

  # Set this to appropriate ingress service for which the options are :
  # :relay for Exim, Postfix, Qmail
  # :mailgun for Mailgun
  # :mandrill for Mandrill
  # :postmark for Postmark
  # :sendgrid for Sendgrid
  config.action_mailbox.ingress = ENV.fetch('RAILS_INBOUND_EMAIL_SERVICE', 'relay').to_sym
end
