class Api::V1::Accounts::NotificationSettingsController < Api::V1::Accounts::BaseController

  before_action :set_user, :load_notification_setting

  def show
    success_response(
      data: NotificationSettingSerializer.serialize(@notification_setting),
      message: 'Notification settings retrieved successfully'
    )
  end

  def update
    update_flags
    @notification_setting.save!
    
    success_response(
      data: NotificationSettingSerializer.serialize(@notification_setting),
      message: 'Notification settings updated successfully'
    )
  rescue ActiveRecord::RecordInvalid => e
    error_response(
      code: ApiErrorCodes::VALIDATION_ERROR,
      message: e.message
    )
  end

  private

  def set_user
    @user = current_user
  end

  def load_notification_setting
    @notification_setting = @user.notification_settings.find_or_initialize_by(account_id: Current.account.id)
    @notification_setting.save! if @notification_setting.new_record?
  end

  def notification_setting_params
    params.require(:notification_settings).permit(selected_email_flags: [], selected_push_flags: [])
  end

  def update_flags
    @notification_setting.selected_email_flags = notification_setting_params[:selected_email_flags]
    @notification_setting.selected_push_flags = notification_setting_params[:selected_push_flags]
  end
end
