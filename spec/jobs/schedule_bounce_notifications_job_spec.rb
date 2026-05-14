require "rails_helper"

RSpec.describe ScheduleBounceNotificationsJob do
  before do
    allow(SendBounceNotificationsJob).to receive(:perform_later)

    travel_to Time.zone.local(2026, 5, 12, 15, 0, 0) do
      described_class.perform_now
    end
  end

  it "schedules a SendBounceNotifications job to send to group admins with yesterday's date" do
    expect(SendBounceNotificationsJob).to have_received(:perform_later)
                                            .with({ bounced_on_date: Date.new(2026, 5, 11), user_role: :group_admin })
                                            .once
  end

  it "schedules a SendBounceNotifications job to send to organisation admins with a date of 8 days ago" do
    expect(SendBounceNotificationsJob).to have_received(:perform_later)
                                            .with({ bounced_on_date: Date.new(2026, 5, 4), user_role: :organisation_admin })
                                            .once
  end
end
