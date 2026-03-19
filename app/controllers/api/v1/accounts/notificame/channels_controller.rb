class Api::V1::Accounts::Notificame::ChannelsController < Api::V1::Accounts::BaseController
  skip_before_action :authenticate_user!, :authenticate_access_token!, :set_current_user, raise: false
  def index
    channels = Whatsapp::Providers::NotificameService.list_channels(params[:token])
    render json: { channels: channels }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
