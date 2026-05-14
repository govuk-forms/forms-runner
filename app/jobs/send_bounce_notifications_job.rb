class SendBounceNotificationsJob < ApplicationJob
  queue_as :bounce_notifications

  def perform(bounced_on_date:, user_role:)
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    bounced_deliveries = Delivery.bounced_on_day(bounced_on_date)
    bounced_deliveries.group_by(&:form_id).each do |form_id, deliveries|
      form = deliveries.first.form
      group = Api::V2::GroupResource.find(form_id)

      users = user_role == :organisation_admin ? group.organisation.organisation_admin_users : group.group_admin_users

      users.each do |user|
        BounceNotificationMailer.bounce_notification_email(
          form:, group_name: group.name, user:, user_role:, deliveries:, bounced_on_date:,
        ).deliver_now
      end

      Rails.logger.info "Sent bounce notifications to #{user_role.to_s.gsub('_', ' ')} users for bounced deliveries on #{bounced_on_date.strftime('%-d %B %Y')} for form #{form_id}"
    end
  end
end
