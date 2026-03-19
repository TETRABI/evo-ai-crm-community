class ApplicationMailer < ActionMailer::Base
  include ActionView::Helpers::SanitizeHelper

  default from: proc { ApplicationMailer.get_mailer_sender_email }
  before_action { ensure_current_account(params.try(:[], :account)) }
  around_action :switch_locale
  layout 'mailer/base'
  # Fetch template from Database if available
  # Order: Account Specific > Installation Specific > Fallback to file
  prepend_view_path ::MessageTemplate.resolver
  append_view_path Rails.root.join('app/views/mailers')
  helper :frontend_urls
  helper do
    def global_config
      @global_config ||= GlobalConfig.get('BRAND_NAME', 'BRAND_URL')
    end
  end

  rescue_from(*ExceptionList::SMTP_EXCEPTIONS, with: :handle_smtp_exceptions)

  def smtp_config_set_or_development?
    ENV.fetch('SMTP_ADDRESS', nil).present? || Rails.env.development?
  end

  private

  def handle_smtp_exceptions(message)
    Rails.logger.warn 'Failed to send Email'
    Rails.logger.error "Exception: #{message}"
  end

  def send_mail_with_liquid(*args)
    Rails.logger.info "📤 EMAIL: Preparing to send email to #{args[0][:to]} with subject '#{args[0][:subject]}'"
    Rails.logger.info "📤 EMAIL: Using delivery method: #{ActionMailer::Base.delivery_method}"

    mail_obj = mail(*args) do |format|
      # explored sending a multipart email containing both text type and html
      # parsing the html with nokogiri will remove the links as well
      # might also remove tags like b,li etc. so lets rethink about this later
      # format.text { Nokogiri::HTML(render(layout: false)).text }
      format.html { render }
    end

    Rails.logger.info "📤 EMAIL: Mail object created, ready for delivery"
    mail_obj
  end

  def liquid_droppables
    # Merge additional objects into this in your mailer
    # liquid template handler converts these objects into drop objects
    {
      account: Current.account,
      user: @agent,
      conversation: @conversation,
      inbox: @conversation&.inbox
    }
  end

  def liquid_locals
    # expose variables you want to be exposed in liquid
    locals = {
      global_config: GlobalConfig.get('BRAND_NAME', 'BRAND_URL'),
      action_url: @action_url
    }

    locals.merge({ attachment_url: @attachment_url }) if @attachment_url
    locals.merge({ failed_contacts: @failed_contacts, imported_contacts: @imported_contacts })
    locals
  end

  def locale_from_account(account)
    return unless account

    I18n.available_locales.map(&:to_s).include?(account.locale) ? account.locale : nil
  end

  def self.get_mailer_sender_email
    begin
      # Try GlobalConfig first, then fallback to ENV
      sender_email = GlobalConfigService.load('MAILER_SENDER_EMAIL', nil) if defined?(GlobalConfigService)
      sender_email.presence || ENV.fetch('MAILER_SENDER_EMAIL', 'Evolution <accounts@evoai.app>')
    rescue => e
      Rails.logger.warn "Failed to load MAILER_SENDER_EMAIL from GlobalConfig: #{e.message}" if defined?(Rails.logger)
      ENV.fetch('MAILER_SENDER_EMAIL', 'Evolution <accounts@evoai.app>')
    end
  end

  def ensure_current_account(account)
    Current.reset
    Current.account = account if account.present?
  end

  def switch_locale(&)
    locale ||= locale_from_account(Current.account)
    locale ||= I18n.default_locale
    # ensure locale won't bleed into other requests
    # https://guides.rubyonrails.org/i18n.html#managing-the-locale-across-requests
    I18n.with_locale(locale, &)
  end
end
