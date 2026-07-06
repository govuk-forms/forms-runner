class SendBounceNotificationsJob < ApplicationJob
  queue_as :bounce_notifications

  def perform(bounced_on_date:, is_escalation:)
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    bounced_deliveries = Delivery.bounced_on_day(bounced_on_date)
    bounced_deliveries.group_by(&:form_id).each do |form_id, deliveries|
      CurrentJobLoggingAttributes.form_id = form_id

      form = deliveries.first.form
      CurrentJobLoggingAttributes.form_name = form.name

      group = Api::V2::GroupResource.find(form_id)

      if !is_escalation && group.group_admin_users.any?
        users = group.group_admin_users
        user_role = :group_admin
      else
        users = group.organisation.organisation_admin_users
        user_role = :organisation_admin
      end

      users.each do |user|
        BounceNotificationMailer.bounce_notification_email(
          form:, group_name: group.name, user:, user_role:, deliveries:,
        ).deliver_now
      end

      if users.any?
        Rails.logger.info "Sent bounce notifications to #{users.length} #{user_role.to_s.gsub('_', ' ')} users for bounced deliveries on #{bounced_on_date.strftime('%-d %B %Y')} for form #{form_id}"
      else
        Rails.logger.info "No #{user_role.to_s.gsub('_', ' ')} users for form #{form_id}, no bounce notifications sent"
      end
    end
  end
end
