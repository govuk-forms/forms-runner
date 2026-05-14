require "rails_helper"

RSpec.describe SendBounceNotificationsJob, :capture_logging do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  let(:bounced_on_date) { Date.new(2026, 5, 6) }
  let(:user_role) { :group_admin }

  let(:form_with_bounces) { build :form }
  let(:other_form_with_bounces) { build :form }
  let(:form_without_bounces) { build :form }
  let(:group) { build :group, group_admin_users_count: 1 }
  let(:other_group) { build :group, group_admin_users_count: 1 }

  let(:req_headers) { { "Accept" => "application/json" } }

  before do
    create_list :delivery, 2, :bounced, :immediate, form_id: form_with_bounces.id, failed_at: Time.zone.local(2026, 5, 5, 23, 0, 0)
    create :delivery, :delivered, :immediate, form_id: form_without_bounces.id

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form_with_bounces.form_id}/group", req_headers, group.to_json, 200
      mock.get "/api/v2/forms/#{other_form_with_bounces.form_id}/group", req_headers, other_group.to_json, 200
    end
  end

  context "when there are multiple forms with bounces on the date" do
    before do
      create_list :delivery, 2, :bounced, :daily_scheduled_delivery, form_id: other_form_with_bounces.id, failed_at: Time.zone.local(2026, 5, 6, 22, 59, 0)
      described_class.perform_now(bounced_on_date:, user_role:)
    end

    it "sends an email per form with bounced submissions" do
      expect(ActionMailer::Base.deliveries.size).to eq 2
      expect(ActionMailer::Base.deliveries.map(&:to).flatten).to contain_exactly(
        group.group_admin_users.first.email,
        other_group.group_admin_users.first.email,
      )
    end

    it "logs a message for each form with bounced submissions" do
      expect(log_lines).to include(
        hash_including(
          "level" => "INFO",
          "message" => "Sent bounce notifications to group admin users for bounced deliveries on 6 May 2026 for form #{form_with_bounces.form_id}",
        ),
        hash_including(
          "level" => "INFO",
          "message" => "Sent bounce notifications to group admin users for bounced deliveries on 6 May 2026 for form #{other_form_with_bounces.form_id}",
        ),
      )
    end
  end

  context "when notifying the group admins" do
    let(:user_role) { :group_admin }
    let(:group) { build :group, group_admin_users_count: 2 }

    before do
      described_class.perform_now(bounced_on_date:, user_role:)
    end

    it "sends an email to each group admin" do
      expect(ActionMailer::Base.deliveries.size).to eq 2
      expect(ActionMailer::Base.deliveries.map(&:to).flatten).to contain_exactly(
        group.group_admin_users.first.email,
        group.group_admin_users.second.email,
      )
    end

    it "logs that it sent the notifications to the group admins" do
      expect(log_lines).to include(
        hash_including(
          "level" => "INFO",
          "message" => "Sent bounce notifications to group admin users for bounced deliveries on 6 May 2026 for form #{form_with_bounces.form_id}",
        ),
      )
    end
  end

  context "when notifying the organisation admins" do
    let(:user_role) { :organisation_admin }
    let(:group) { build :group, group_admin_users_count: 1, organisation_admin_users_count: 2 }

    before do
      described_class.perform_now(bounced_on_date:, user_role:)
    end

    it "sends an email to each organisation admin" do
      expect(ActionMailer::Base.deliveries.size).to eq 2
      expect(ActionMailer::Base.deliveries.map(&:to).flatten).to contain_exactly(
        group.organisation.organisation_admin_users.first.email,
        group.organisation.organisation_admin_users.second.email,
      )
    end

    it "logs that it sent the notifications to the organisation admins" do
      expect(log_lines).to include(
        hash_including(
          "level" => "INFO",
          "message" => "Sent bounce notifications to organisation admin users for bounced deliveries on 6 May 2026 for form #{form_with_bounces.form_id}",
        ),
      )
    end
  end
end
