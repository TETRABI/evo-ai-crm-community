# frozen_string_literal: true

class Api::V1::Accounts::DashboardController < Api::V1::Accounts::BaseController
  require_permissions({
    customer: 'dashboard.read'
  })

  def customer
    dashboard_data = Dashboard::CustomerDashboardService.new(
      account: Current.account,
      params: dashboard_params
    ).call

    success_response(
      data: dashboard_data,
      message: 'Customer dashboard data retrieved successfully'
    )
  end

  private

  def dashboard_params
    params.permit(:pipeline_id, :team_id, :inbox_id, :user_id, :since, :until)
  end
end
