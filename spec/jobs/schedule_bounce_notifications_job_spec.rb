require "rails_helper"

RSpec.describe ScheduleBounceNotificationsJob do
  it "schedules a SendBounceNotifications job with yesterday's date" do
    expect(SendBounceNotificationsJob).to receive(:perform_later)
                                            .with(bounced_on_date: Time.zone.yesterday.to_date, user_role: :group_admin)

    described_class.perform_now
  end
end
