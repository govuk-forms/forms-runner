require "rails_helper"

RSpec.describe BounceNotificationMailer do
  describe "#bounce_notification_to_group_admins_email" do
    subject(:mail) do
      described_class.bounce_notification_email(form:, user:, deliveries:, user_role:)
    end

    let(:deliveries) { create_list :delivery, 3, :bounced, :immediate }
    let(:user) { build :admin_user }
    let(:form) { build :form }
    let(:user_role) { :group_admin }

    before do
      Settings.govuk_notify.bounce_notification_to_group_admins_template_id = "some-template-id"
    end

    describe "basic personalisation" do
      it "includes personalisation for the user and form" do
        expect(mail.govuk_notify_personalisation).to include(
          user_name: user.name,
          submission_email: form.submission_email,
          form_name: form.name,
        )
      end

      it "sets the to email address" do
        expect(mail.to).to eq [user.email]
      end

      it "sets the template" do
        expect(mail.govuk_notify_template).to eq "some-template-id"
      end
    end

    describe "personalisation for the user role" do
      context "when sending to an organisation admin" do
        let(:user_role) { :organisation_admin }

        it "sets is_organisation_admin to yes" do
          expect(mail.govuk_notify_personalisation[:is_organisation_admin]).to eq "yes"
        end

        it "sets is_group_admin to no" do
          expect(mail.govuk_notify_personalisation[:is_group_admin]).to eq "no"
        end
      end

      context "when sending to a group admin" do
        let(:user_role) { :group_admin }

        it "sets is_organisation_admin to no" do
          expect(mail.govuk_notify_personalisation[:is_organisation_admin]).to eq "no"
        end

        it "sets is_group_admin to yes" do
          expect(mail.govuk_notify_personalisation[:is_group_admin]).to eq "yes"
        end
      end
    end

    describe "personalisation for the bounced deliveries list" do
      let(:latest_immediate_delivery) do
        submission = create(:submission, reference: "LATEST")
        create(:delivery, :bounced, :immediate, last_attempt_at: Time.zone.local(2026, 5, 7, 11, 22, 20), submissions: [submission])
      end
      let(:earliest_immediate_delivery) do
        submission = create(:submission, reference: "EARLIEST")
        create(:delivery, :bounced, :immediate, last_attempt_at: Time.zone.local(2026, 5, 7, 9, 20, 5), submissions: [submission])
      end
      let(:daily_delivery) { create :delivery, :bounced, :daily_scheduled_delivery, last_attempt_at: Time.zone.local(2026, 5, 7, 10, 10, 0) }
      let(:weekly_delivery) { create :delivery, :bounced, :weekly_scheduled_delivery, last_attempt_at: Time.zone.local(2026, 5, 7, 6, 23, 0) }

      context "when there are bounced submissions and bounced batches" do
        let(:deliveries) { [latest_immediate_delivery, earliest_immediate_delivery, daily_delivery, weekly_delivery] }

        it "includes the correct boolean personalisation" do
          expect(mail.govuk_notify_personalisation).to include(has_bounced_submissions: "yes",
                                                               has_bounced_batches: "yes")
        end

        it "includes a list of bounced submissions ordered by sent date with times in London time" do
          expect(mail.govuk_notify_personalisation[:bounced_submissions_list])
            .to eq ["EARLIEST at 10:20am on 7 May 2026", "LATEST at 12:22pm on 7 May 2026"]
        end

        it "includes a list of bounced batches ordered by sent date with times in London time" do
          expect(mail.govuk_notify_personalisation[:bounced_batches_list])
            .to eq ["Weekly batch sent at 7:23am on 7 May 2026", "Daily batch sent at 11:10am on 7 May 2026"]
        end
      end

      context "when there are no bounced submissions" do
        let(:deliveries) { [daily_delivery] }

        it "sets has_bounced_submissions to no" do
          expect(mail.govuk_notify_personalisation).to include(has_bounced_submissions: "no")
        end

        it "sets the bounced_submissions_list to an empty array" do
          expect(mail.govuk_notify_personalisation).to include(bounced_submissions_list: [])
        end
      end

      context "when there are no bounced batches" do
        let(:deliveries) { [earliest_immediate_delivery] }

        it "sets has_bounced_batches to no" do
          expect(mail.govuk_notify_personalisation).to include(has_bounced_batches: "no")
        end

        it "sets the bounced_batches_list to an empty array" do
          expect(mail.govuk_notify_personalisation).to include(bounced_batches_list: [])
        end
      end
    end

    describe "personalisation for the bounce type" do
      context "when the bounce is a hard bounce" do
        let(:deliveries) { [create(:delivery, :bounced, :immediate, bounce_type: "Permanent")] }

        it "sets hard_bounce to yes and soft_bounce to no" do
          expect(mail.govuk_notify_personalisation).to include(hard_bounce: "yes", soft_bounce: "no")
        end
      end

      context "when the bounce is a soft bounce" do
        let(:deliveries) { [create(:delivery, :bounced, :immediate, bounce_type: "Transient")] }

        it "sets hard_bounce to no and soft_bounce to yes" do
          expect(mail.govuk_notify_personalisation).to include(hard_bounce: "no", soft_bounce: "yes")
        end
      end
    end

    describe "personalisation for the deadline date" do
      let(:latest_submission) { create(:submission, created_at: Time.zone.local(2026, 5, 7, 9, 20, 5)) }
      let(:earliest_submission) { create(:submission, created_at: Time.zone.local(2026, 5, 5, 23, 0, 0)) }

      context "when there only immediate submission deliveries" do
        let(:deliveries) do
          [create(:delivery, submissions: [latest_submission]), create(:delivery, submissions: [earliest_submission])]
        end

        it "sets the deadline date to 30 days after the earliest submission created_at date in London time" do
          expect(mail.govuk_notify_personalisation[:deadline_date]).to eq("5 June 2026")
        end
      end

      context "when there is a bounced batch delivery" do
        let(:deliveries) do
          [create(:delivery, :weekly, submissions: [latest_submission, earliest_submission])]
        end

        it "sets the deadline date to 30 days after the earliest submission created_at date in London time" do
          expect(mail.govuk_notify_personalisation[:deadline_date]).to eq("5 June 2026")
        end
      end
    end
  end
end
