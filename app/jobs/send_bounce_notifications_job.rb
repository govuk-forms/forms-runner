class SendBounceNotificationsJob < ApplicationJob
  queue_as :bounce_notifications

  def perform(bounced_on_date:)
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    bounced_deliveries = Delivery.bounced_on_day(bounced_on_date)
    bounced_deliveries.group_by(&:form_id).each do |form_id, deliveries|
      form = deliveries.first.form
      group = Api::V2::GroupResource.find(form_id)

      group.group_admin_users.each do |user|
        BounceNotificationMailer.bounce_notification_email(form:, user:, deliveries:, user_role: :group_admin).deliver_now
      end

      Rails.logger.info "Sent bounce notifications to group admins for bounced deliveries on #{bounced_on_date.strftime('%-d %B %Y')} for form #{form_id}"
    end
  end
end
