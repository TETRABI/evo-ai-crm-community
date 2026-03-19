class Whatsapp::CallbacksController < ApplicationController
  def show
    Rails.logger.info "WhatsApp callback controller called with params: #{params.inspect}"
    Rails.logger.info "Request URL: #{request.url}"
    Rails.logger.info "Request referer: #{request.referer}"

    # Check if WhatsApp redirected with an error (user canceled authorization)
    if params[:error].present?
      Rails.logger.error "WhatsApp callback error: #{params[:error]}"
      handle_authorization_error
      return
    end

    Rails.logger.info 'WhatsApp callback success, redirecting to setup page'
    # For WhatsApp, we just redirect to the setup page with the authorization code
    # The actual token exchange will be handled by the Vue.js frontend
    redirect_to_setup_page
  rescue StandardError => e
    handle_error(e)
  end

  private

  def redirect_to_setup_page
    redirect_to app_new_whatsapp_inbox_url(
      account_id: account_id,
      code: params[:code],
      state: params[:state]
    )
  end

  def handle_authorization_error
    error_info = {
      'error_type' => params[:error] || 'authorization_error',
      'code' => 400,
      'error_message' => params[:error_description] || 'Authorization was denied'
    }

    Rails.logger.error("WhatsApp Authorization Error: #{error_info['error_message']}")
    redirect_to_error_page(error_info)
  end

  def handle_error(error)
    Rails.logger.error("WhatsApp Channel creation Error: #{error.message}")
    EvolutionExceptionTracker.new(error).capture_exception

    error_info = {
      'error_type' => error.class.name,
      'code' => 500,
      'error_message' => error.message
    }

    redirect_to_error_page(error_info)
  end

  def redirect_to_error_page(error_info)
    redirect_to app_new_whatsapp_inbox_url(
      account_id: account_id,
      error_type: error_info['error_type'],
      code: error_info['code'],
      error_message: error_info['error_message']
    )
  end

  def account_id
    # Extract account_id from state parameter if present
    # or from URL path
    params[:state] || extract_account_id_from_referrer
  end

  def extract_account_id_from_referrer
    # Extract account ID from referrer URL if available
    # This is a fallback if state parameter is not provided
    referrer = request.referer
    return '1' unless referrer # default fallback

    # Extract account ID from URL like: http://localhost:3000/app/accounts/1/settings/inboxes/new/whatsapp
    match = referrer.match(%r{/app/accounts/(\d+)/})
    match ? match[1] : '1'
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
