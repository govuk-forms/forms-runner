class BounceNotificationMailer < GovukNotifyRails::Mailer
  include NotifyUtils

  def bounce_notification_email(form:, user:, deliveries:, user_role:)
    set_template(Settings.govuk_notify.bounce_notification_to_group_admins_template_id)

    # We're assuming that all bounces are for the same reason
    hard_bounce = hard_bounce?(deliveries.first)

    bounced_submissions = bounced_submissions(deliveries)
    bounced_batches = bounced_batches(deliveries)

    set_personalisation(
      user_name: user.name,
      submission_email: form.submission_email,
      form_name: form.name,
      has_bounced_submissions: make_notify_boolean(bounced_submissions.any?),
      bounced_submissions_list: bounced_submissions,
      has_bounced_batches: make_notify_boolean(bounced_batches.any?),
      bounced_batches_list: bounced_batches,
      hard_bounce: make_notify_boolean(hard_bounce),
      soft_bounce: make_notify_boolean(!hard_bounce),
      deadline_date: deadline_date(deliveries),
      is_organisation_admin: make_notify_boolean(user_role == :organisation_admin),
      is_group_admin: make_notify_boolean(user_role == :group_admin),
    )

    mail(to: user.email)
  end

private

  def hard_bounce?(delivery)
    delivery.failure_details&.[]("bounceType") == "Permanent"
  end

  def bounced_submissions(deliveries)
    deliveries.select(&:immediate?).sort_by(&:last_attempt_at).map do |delivery|
      sent_at = delivery.last_attempt_at.in_time_zone(TimeZoneUtils.submission_time_zone)

      I18n.t("mailer.bounce_notification.bounced_submission",
             submission_reference: delivery.submissions.sole.reference,
             sent_at_time: sent_at.strftime("%l:%M%P").strip,
             sent_at_date: sent_at.strftime("%-d %B %Y"))
    end
  end

  def bounced_batches(deliveries)
    deliveries.select { |d| %w[daily weekly].include?(d.delivery_schedule) }.sort_by(&:last_attempt_at).map do |delivery|
      sent_at = delivery.last_attempt_at.in_time_zone(TimeZoneUtils.submission_time_zone)
      sent_at_time = sent_at.strftime("%l:%M%P").strip
      sent_at_date = sent_at.strftime("%-d %B %Y")

      if delivery.daily?
        I18n.t("mailer.bounce_notification.bounced_daily_batch", sent_at_time:, sent_at_date:)
      else
        I18n.t("mailer.bounce_notification.bounced_weekly_batch", sent_at_time:, sent_at_date:)
      end
    end
  end

  def deadline_date(deliveries)
    delivery_ids = deliveries.map(&:id)
    earliest_submission_created_at = Submission.joins(:submission_deliveries).where(submission_deliveries: { delivery_id: delivery_ids }).minimum(:created_at)
    earliest_submission_date_time = earliest_submission_created_at.in_time_zone(TimeZoneUtils.submission_time_zone)
    deadline_date_time = earliest_submission_date_time + Settings.submissions.maximum_retention_seconds.seconds
    deadline_date_time.strftime("%-d %B %Y")
  end
end
