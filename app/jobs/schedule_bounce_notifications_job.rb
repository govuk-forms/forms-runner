class ScheduleBounceNotificationsJob < ApplicationJob
  queue_as :bounce_notifications

  def perform
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    SendBounceNotificationsJob.perform_later(bounced_on_date: 1.day.ago.to_date, user_role: :group_admin)
    SendBounceNotificationsJob.perform_later(bounced_on_date: 8.days.ago.to_date, user_role: :organisation_admin)
  end
end
