class Api::V1::Accounts::WebhooksController < Api::V1::Accounts::BaseController
  require_permissions({
    index: 'webhooks.read',
    create: 'webhooks.create',
    update: 'webhooks.update',
    destroy: 'webhooks.delete'
  })

  before_action :fetch_webhook, only: [:update, :destroy]

  def index
    @webhooks = Current.account.webhooks
    
    apply_pagination
    
    paginated_response(
      data: WebhookSerializer.serialize_collection(@webhooks),
      collection: @webhooks,
      message: 'Webhooks retrieved successfully'
    )
  end

  def create
    @webhook = Current.account.webhooks.new(webhook_create_params)
    @webhook.save!
    
    success_response(
      data: WebhookSerializer.serialize(@webhook),
      message: 'Webhook created successfully',
      status: :created
    )
  rescue ActiveRecord::RecordInvalid => e
    error_response(
      code: ApiErrorCodes::VALIDATION_ERROR,
      message: e.message
    )
  end

  def update
    @webhook.update!(webhook_update_params)
    
    success_response(
      data: WebhookSerializer.serialize(@webhook),
      message: 'Webhook updated successfully'
    )
  rescue ActiveRecord::RecordInvalid => e
    error_response(
      code: ApiErrorCodes::VALIDATION_ERROR,
      message: e.message
    )
  end

  def destroy
    @webhook.destroy!
    
    success_response(
      data: nil,
      message: 'Webhook deleted successfully'
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    error_response(
      code: ApiErrorCodes::CANNOT_DELETE_RESOURCE,
      message: e.message
    )
  end

  private

  def webhook_create_params
    params.require(:webhook).permit(:inbox_id, :name, :url, subscriptions: [])
  end

  def webhook_update_params
    params.require(:webhook).permit(:name, subscriptions: [])
  end

  def fetch_webhook
    @webhook = Current.account.webhooks.find(params[:id])
  end
end
