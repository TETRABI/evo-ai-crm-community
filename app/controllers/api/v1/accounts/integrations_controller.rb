class Api::V1::Accounts::IntegrationsController < Api::V1::Accounts::BaseController
  private

  def permitted_params
    params.require(:integrations_hook).permit!
  end

  def set_hook
    @hook = Current.account.hooks.find(params[:id])
  end

  def process_event_payload
    params.require(:hook_id)
    params.require(:event)
  end
end
