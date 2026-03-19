class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # TELEMETRY DISABLED BY DEFAULT: No external version checks
    Rails.logger.info 'Version check blocked for privacy'
    return
  end

  private

  def update_version_info
    # DISABLED: No external version updates
    return
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
