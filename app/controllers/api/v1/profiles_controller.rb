class Api::V1::ProfilesController < Api::BaseController
  before_action :set_user

  def show
    success_response(data: profile_data(@user), message: 'Profile retrieved successfully')
  end

  def update
    # Password update moved to evo-auth-service
    @user.assign_attributes(profile_params)
    @user.custom_attributes.merge!(custom_attributes_params)
    @user.save!
  end

  def avatar
    @user.avatar.attachment.destroy! if @user.avatar.attached?
    @user.reload
  end

  def auto_offline
    @user.account_users.find_by!(account_id: auto_offline_params[:account_id]).update!(auto_offline: auto_offline_params[:auto_offline] || false)
  end

  def availability
    @user.account_users.find_by!(account_id: availability_params[:account_id]).update!(availability: availability_params[:availability])

    Rails.configuration.dispatcher.dispatch(Events::Types::ACCOUNT_PRESENCE_UPDATED, Time.zone.now, account_id: availability_params[:account_id],
                                                                                                    user_id: @current_user.id,
                                                                                                    status: availability_params[:availability])
  end

  def set_active_account
    @user.account_users.find_by(account_id: profile_params[:account_id]).update!(active_at: Time.now.utc)
    head :ok
  end

  # def resend_confirmation - moved to evo-auth-service

  # def reset_access_token - moved to evo-auth-service

  private

  def set_user
    @user = current_user
  end

  def availability_params
    params.require(:profile).permit(:account_id, :availability)
  end

  def auto_offline_params
    params.require(:profile).permit(:account_id, :auto_offline)
  end

  def profile_params
    params.require(:profile).permit(
      :email,
      :name,
      :display_name,
      :avatar,
      :message_signature,
      :account_id,
      ui_settings: {}
    )
  end

  def custom_attributes_params
    params.require(:profile).permit(:phone_number)
  end

  # def password_params - moved to evo-auth-service
end
