class ScheduleBounceNotificationsJob < ApplicationJob
  queue_as :bounce_notifications

  def perform
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    SendBounceNotificationsJob.perform_later(bounced_on_date: Time.zone.yesterday.to_date, user_role: :group_admin)
  end
end
