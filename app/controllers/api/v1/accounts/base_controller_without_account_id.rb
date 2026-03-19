# frozen_string_literal: true

# Base controller for account-scoped routes WITHOUT account_id in URL
# Padrão: accountId deve estar apenas no header account-id (conforme API_RESPONSE_STANDARD.md)
# Este controller permite rotas como /api/v1/accounts/inboxes em vez de /api/v1/accounts/:account_id/inboxes
class Api::V1::Accounts::BaseControllerWithoutAccountId < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper
  include ApiResponseHelper
  
  before_action :current_account
  around_action :switch_locale_using_account_locale

  private

  def paginate_instance_variables(page, per_page)
    %w[
      @contacts
      @conversations
      @inboxes
      @labels
      @teams
      @team_members
      @canned_responses
      @webhooks
      @macros
      @agent_bots
      @notifications
      @automation_rules
      @custom_filters
      @custom_attribute_definitions
      @dashboard_apps
      @scheduled_actions
      @scheduled_action_templates
      @templates
      @pipeline_items
      @pipeline_stages
      @pipeline_tasks
      @pipelines
      @csat_survey_responses
      @messages
      @notes
    ].each do |var_name|
      var = instance_variable_get(var_name)
      next unless var.respond_to?(:page)

      instance_variable_set(var_name, var.page(page).per(per_page))
    end
  end
end

