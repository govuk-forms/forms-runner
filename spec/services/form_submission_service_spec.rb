require "rails_helper"

RSpec.describe FormSubmissionService, :capture_logging do
  include ActiveJob::TestHelper

  subject(:service) { described_class.call(current_context:, email_confirmation_input:, mode:) }

  let(:mode) { Mode.new }
  let(:confirmation_email_address) { "testing@gov.uk" }
  let(:email_confirmation_input) { build :email_confirmation_input_opted_in, confirmation_email_address: }
  let(:form) { Form.new(form_document) }
  let(:welsh_form) { Form.new(welsh_form_document) }

  let(:form_document) do
    build(
      :v2_form_document,
      form_id: 1,
      name: "Form 1",
      what_happens_next_markdown:,
      support_email:,
      support_phone:,
      support_url:,
      support_url_text:,
      submission_email:,
      payment_url:,
      steps:,
      language: "en",
      delivery_configurations:,
    )
  end
  let(:document_json) { form_document.as_json }

  let(:welsh_form_document) do
    build(
      :v2_form_document,
      form_id: 1,
      name: "Welsh Form 1",
      what_happens_next_markdown:,
      support_email:,
      support_phone:,
      support_url:,
      support_url_text:,
      submission_email:,
      payment_url:,
      steps:,
      language: "cy",
    )
  end
  let(:welsh_document_json) { welsh_form_document.as_json }

  let(:steps) { [build(:v2_question_step, id: 2, answer_type: "text")] }
  let(:what_happens_next_markdown) { "We usually respond to applications within 10 working days." }
  let(:support_email) { Faker::Internet.email(domain: "example.gov.uk") }
  let(:support_phone) { Faker::Lorem.paragraph(sentence_count: 2, supplemental: true, random_sentences_to_add: 4) }
  let(:support_url) { Faker::Internet.url(host: "gov.uk") }
  let(:support_url_text) { Faker::Lorem.sentence(word_count: 1, random_words_to_add: 4) }
  let(:payment_url) { nil }
  let(:submission_email) { "testing@gov.uk" }
  let(:delivery_configurations) { [build(:v2_delivery_configuration, :immediate_email)] }

  let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }

  let(:step) { OpenStruct.new({ question_text: "What is the meaning of life?", show_answer_in_email: "42" }) }
  let(:all_steps) { [step] }
  let(:journey) { instance_double(Flow::Journey, completed_steps: all_steps, all_steps:) }
  let(:answers) do
    {
      "1" => {
        selection: "Option 1",
      },
      "2" => {
        text: "Example text",
      },
    }
  end
  let(:locales_used) { [:en] }
  let(:wants_copy_of_answers) { false }
  let(:copy_of_answers_email_address) { nil }
  let(:will_send_copy_of_answers) { wants_copy_of_answers && copy_of_answers_email_address.present? }
  let(:current_context) do
    instance_double(Flow::Context, form:, journey:, completed_steps: all_steps, answers:, locales_used:,
                                   wants_copy_of_answers?: wants_copy_of_answers,
                                   get_copy_of_answers_email_address: copy_of_answers_email_address,
                                   will_send_copy_of_answers?: will_send_copy_of_answers)
  end

  before do
    allow(ReferenceNumberService).to receive(:generate).and_return(reference)
  end

  describe "#submit" do
    it "returns the submission reference" do
      expect(service.submit).to eq reference
    end

    it "includes the submission reference in the logging context" do
      service.submit
      expect(log_line["submission_reference"]).to eq(reference)
    end

    it "records a submission count metric" do
      expect(Metrics).to receive(:record_submission).with(
        form_id: form.id,
        form_name: form.name,
        mode:,
      )

      service.submit
    end

    shared_examples "logging" do
      it "logs submission" do
        allow(LogEventService).to receive(:log_submit).once

        service.submit

        expect(LogEventService).to have_received(:log_submit).with(
          current_context,
          requested_email_confirmation: true,
          preview: mode.preview?,
        )
      end
    end

    describe "submitting the form to the processing team" do
      context "when the submission type is s3" do
        let(:delivery_configurations) { [build(:v2_delivery_configuration, :immediate_s3, formats: %w[csv])] }

        it "enqueues a job to send the submission to S3" do
          assert_enqueued_with(job: SendS3SubmissionJob) do
            service.submit
          end
        end

        it "saves the submission data" do
          freeze_time do
            expect {
              service.submit
            }.to change(Submission, :count).by(1)
                                           .and change(Delivery, :count).by(1)

            expect(Submission.last).to have_attributes(reference:, form_id: form.id, answers: answers.deep_stringify_keys,
                                                       mode: "form", form_document: document_json,
                                                       submission_locale: "en", created_at: Time.zone.now)

            expect(Submission.last.deliveries.sole).to have_attributes(
              delivery_reference: nil,
              last_attempt_at: nil,
              delivery_method: "s3",
              delivery_schedule: "immediate",
              formats: %w[csv],
            )
          end
        end

        context "when the job fails to enqueue" do
          let(:enqueue_error) { nil }

          define_negated_matcher :not_change, :change

          before do
            allow(SendS3SubmissionJob).to receive(:perform_later).and_yield(instance_double(SendS3SubmissionJob, successfully_enqueued?: false, enqueue_error:))
          end

          context "and there is no enqueue error" do
            it "raises an error" do
              expect { service.submit }
                .to not_change(Submission, :count)
                      .and not_change(Delivery, :count)
                             .and raise_error(StandardError, "Failed to enqueue delivery for method s3 for submission with reference #{reference}. The submission was deleted, so the user can retry.")
            end
          end

          context "and there is an enqueue error" do
            let(:enqueue_error) { ActiveJob::EnqueueError.new("An error occurred enqueueing job") }

            it "raises an error" do
              expect { service.submit }
                .to not_change(Submission, :count)
                      .and not_change(Delivery, :count)
                             .and raise_error(StandardError, "Failed to enqueue delivery for method s3 for submission with reference #{reference}. The submission was deleted, so the user can retry. Error: An error occurred enqueueing job")
            end
          end
        end

        include_examples "logging"
      end

      context "when the submission type is email" do
        let(:delivery_configurations) { [build(:v2_delivery_configuration, :immediate_email, formats: %w[json])] }

        let(:aws_ses_submission_service_spy) { instance_double(AwsSesSubmissionService) }
        let(:mail_message_id) { "1234" }

        before do
          allow(Flow::Journey).to receive(:new)

          allow(AwsSesSubmissionService).to receive(:new).and_return(aws_ses_submission_service_spy)
          allow(aws_ses_submission_service_spy).to receive(:submit).and_return(mail_message_id)
        end

        it "enqueues a job to send the submission" do
          assert_enqueued_with(job: SendSubmissionJob) do
            service.submit
          end

          expect(aws_ses_submission_service_spy).not_to have_received(:submit)

          perform_enqueued_jobs

          expect(aws_ses_submission_service_spy).to have_received(:submit)
        end

        it "saves the submission data" do
          expect {
            service.submit
          }.to change(Submission, :count).by(1)
                                         .and change(Delivery, :count).by(1)

          expect(Submission.last).to have_attributes(reference:,
                                                     form_id: form.id,
                                                     answers: answers.deep_stringify_keys,
                                                     mode: "form",
                                                     form_document: document_json,
                                                     welsh_form_document: nil,
                                                     submission_locale: "en")
        end

        it "creates a delivery record for the submission" do
          expect {
            service.submit
          }.to change(Delivery, :count).by(1)

          delivery = Submission.last.deliveries.sole
          expect(delivery.delivery_reference).to be_nil
          expect(delivery.last_attempt_at).to be_nil
          expect(delivery.delivery_method).to eq "email"
          expect(delivery.delivery_schedule).to eq "immediate"
          expect(delivery.formats).to eq %w[json]
        end

        context "when the job fails to enqueue" do
          let(:enqueue_error) { nil }

          define_negated_matcher :not_change, :change

          before do
            allow(SendSubmissionJob).to receive(:perform_later).and_yield(instance_double(SendSubmissionJob, successfully_enqueued?: false, enqueue_error:))
          end

          context "and there is no enqueue error" do
            it "raises an error" do
              expect { service.submit }
                .to not_change(Submission, :count)
                      .and not_change(Delivery, :count)
                             .and raise_error(StandardError, "Failed to enqueue delivery for method email for submission with reference #{reference}. The submission was deleted, so the user can retry.")
            end
          end

          context "and there is an enqueue error" do
            let(:enqueue_error) { ActiveJob::EnqueueError.new("An error occurred enqueueing job") }

            it "raises an error" do
              expect { service.submit }
                .to not_change(Submission, :count)
                      .and not_change(Delivery, :count)
                             .and raise_error(StandardError, "Failed to enqueue delivery for method email for submission with reference #{reference}. The submission was deleted, so the user can retry. Error: An error occurred enqueueing job")
            end
          end
        end

        include_examples "logging"
      end

      context "when the form has both email and s3 delivery configurations" do
        let(:email_confirmation_input) { build :email_confirmation_input }
        let(:delivery_configurations) do
          [
            build(:v2_delivery_configuration, :immediate_email),
            build(:v2_delivery_configuration, :immediate_s3),
            build(:v2_delivery_configuration, :daily_email), # will be ignored
          ]
        end

        it "enqueues jobs to send by both email and s3" do
          service.submit
          enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
          expect(enqueued_jobs.size).to eq(2)
          expect(enqueued_jobs).to include(hash_including(job: SendSubmissionJob))
          expect(enqueued_jobs).to include(hash_including(job: SendS3SubmissionJob))
        end

        context "and there is an enqueue error with the first job" do
          before do
            enqueue_error = ActiveJob::EnqueueError.new("An error occurred enqueueing job")
            allow(SendSubmissionJob).to receive(:perform_later).and_yield(instance_double(SendSubmissionJob, successfully_enqueued?: false, enqueue_error:))
          end

          it "raises an error and destroys the submission and delivery" do
            expect { service.submit }
              .to not_change(Submission, :count)
                    .and not_change(Delivery, :count)
                           .and raise_error(StandardError, "Failed to enqueue delivery for method email for submission with reference #{reference}. The submission was deleted, so the user can retry. Error: An error occurred enqueueing job")
          end
        end

        context "and there is an enqueue error with the second job" do
          before do
            enqueue_error = ActiveJob::EnqueueError.new("An error occurred enqueueing job")
            allow(SendS3SubmissionJob).to receive(:perform_later).and_yield(instance_double(SendS3SubmissionJob, successfully_enqueued?: false, enqueue_error:))
          end

          it "does not delete the submission or delivery" do
            expect { service.submit }
              .to change(Submission, :count).by(1)
                                            .and change(Delivery, :count).by(2)
          end

          it "updates the delivery to failed" do
            service.submit
            delivery = Submission.last.deliveries.find_by(delivery_method: "s3")
            expect(delivery.failed_at).not_to be_nil
            expect(delivery.failure_reason).to eq("enqueue_failed")
          end

          it "sends an event to Sentry" do
            allow(Sentry).to receive(:capture_message)
            service.submit
            expect(Sentry).to have_received(:capture_message).with("Failed to enqueue submission delivery. Some delivery methods were successfully enqueued, so this delivery needs to be re-attempted by running a rake task", extra: {
              delivery_id: Delivery.last.id,
              delivery_method: "s3",
              submission_reference: reference,
              enqueue_error: "An error occurred enqueueing job",
            })
          end

          it "logs an error" do
            allow(Rails.logger).to receive(:error)
            service.submit
            expect(Rails.logger).to have_received(:error).with("Failed to enqueue submission delivery. Some delivery methods were successfully enqueued, so this delivery needs to be re-attempted by running a rake task", {
              delivery_id: Delivery.last.id,
              delivery_method: "s3",
              enqueue_error: "An error occurred enqueueing job",
            })
          end
        end
      end

      context "when form being submitted is from previewed form" do
        let(:mode) { Mode.new("preview-live") }

        include_examples "logging"
      end

      describe "validations" do
        context "when current context has no completed steps (i.e questions/answers)" do
          let(:current_context) { OpenStruct.new(form:, steps: []) }
          let(:result) { service.submit }

          it "raises an error" do
            expect { result }.to raise_error("Form id(1) has no completed steps i.e questions/answers to submit")
          end
        end
      end

      context "when Welsh has been used to complete the form" do
        let(:locales_used) { %i[en cy] }

        before do
          ActiveResource::HttpMock.respond_to do |mock|
            mock.get "/api/v2/forms/1/live?language=cy", {}, welsh_form_document.to_json, 200
          end
        end

        it "fetches the Welsh form" do
          service.submit
          expect(ActiveResource::HttpMock.requests).to include ActiveResource::Request.new(:get, "/api/v2/forms/1/live?language=cy")
        end

        it "saves the submission data including the Welsh version of the form" do
          expect {
            service.submit
          }.to change(Submission, :count).by(1)

          expect(Submission.last.form_document["language"]).to eq("en")
          expect(Submission.last.form_document["name"]).to eq("Form 1")
          expect(Submission.last.welsh_form_document["language"]).to eq("cy")
          expect(Submission.last.welsh_form_document["name"]).to eq("Welsh Form 1")
        end
      end

      context "when form is not in english" do
        let(:form) { welsh_form }

        before do
          ActiveResource::HttpMock.respond_to do |mock|
            mock.get "/api/v2/forms/1/live", {}, document_json.to_json, 200
          end
        end

        it "fetches the default language form" do
          service.submit
          expect(ActiveResource::HttpMock.requests).to include ActiveResource::Request.new(:get, "/api/v2/forms/1/live")
        end

        it "saves the submission data with the English version of the form" do
          expect {
            service.submit
          }.to change(Submission, :count).by(1)

          expect(Submission.last.form_document["language"]).to eq("en")
          expect(Submission.last.form_document["name"]).to eq("Form 1")
        end

        context "when Welsh has been used to complete the form" do
          let(:locales_used) { %i[en cy] }

          it "saves the original Welsh version of the form on the submission" do
            expect {
              service.submit
            }.to change(Submission, :count).by(1)

            expect(Submission.last.welsh_form_document["language"]).to eq("cy")
            expect(Submission.last.welsh_form_document["name"]).to eq("Welsh Form 1")
          end
        end
      end
    end

    describe "sending the confirmation email to the user" do
      context "when the user has not asked for a copy of their answers" do
        it "enqueues a job to send the confirmation email without a copy of the answers" do
          assert_enqueued_with(job: SendConfirmationEmailJob) do
            service.submit
          end

          args = enqueued_jobs.last["arguments"].first

          expect(args).to include(
            "submission" => hash_including("_aj_globalid"),
            "notify_response_id" => email_confirmation_input.confirmation_email_reference,
            "confirmation_email_address" => confirmation_email_address,
            "include_copy_of_answers" => false,
          )
        end

        context "when the confirmation email job fails to enqueue" do
          let(:enqueue_error) { nil }

          before do
            allow(SendConfirmationEmailJob).to receive(:perform_later).and_yield(instance_double(SendConfirmationEmailJob, successfully_enqueued?: false, enqueue_error:))
          end

          context "and there is no enqueue error" do
            it "raises an error" do
              expect { service.submit }.to change(Submission, :count).by(1).and raise_error(StandardError, "Failed to enqueue confirmation email for reference #{reference}")
            end
          end

          context "and there is an enqueue error" do
            let(:enqueue_error) { ActiveJob::EnqueueError.new("An error occurred enqueueing job") }

            it "raises an error" do
              expect { service.submit }.to change(Submission, :count).by(1).and raise_error(StandardError, "Failed to enqueue confirmation email for reference #{reference}: An error occurred enqueueing job")
            end
          end
        end

        context "when the to email address is rejected by ActionMailer" do
          let(:confirmation_email_address) { "rejected-email@gov.uk\n" }

          it "raises a ConfirmationEmailToAddressError" do
            expect {
              service.submit
            }.to raise_error(FormSubmissionService::ConfirmationEmailToAddressError)
          end

          it "sends an error to Sentry" do
            expect(Sentry).to receive(:capture_message).with("ActionMailer error for To email address in confirmation email", {
              extra: {
                action_mailer_error: /Mail::AddressList can not parse |r\*\*\*\*\*\*\*-e\*\*\*\*(at)g\*\*.u\*\n|: Only able to parse up to "r\*\*\*\*\*\*\*-e\*\*\*\*@g\*\*.u\*\\/,
              },
            })
            service.submit
          rescue FormSubmissionService::ConfirmationEmailToAddressError
            nil
          end

          it "does not queue sending the submission email" do
            assert_no_enqueued_jobs do
              service.submit
            rescue FormSubmissionService::ConfirmationEmailToAddressError
              nil
            end
          end
        end

        context "when user does not want a confirmation email" do
          let(:email_confirmation_input) { build :email_confirmation_input }

          it "does not call FormSubmissionConfirmationMailer" do
            allow(FormSubmissionConfirmationMailer).to receive(:send_confirmation_email)
            service.submit
            expect(FormSubmissionConfirmationMailer).not_to have_received(:send_confirmation_email)
          end
        end
      end

      context "when the user has asked for a copy of their answers" do
        let(:wants_copy_of_answers) { true }
        let(:copy_of_answers_email_address) { "copy-of-answers@example.com" }
        let(:email_confirmation_input) { build :email_confirmation_input }

        it "enqueues a job to send the confirmation email to the copy of answers email with a copy of the answers" do
          assert_enqueued_with(job: SendConfirmationEmailJob) do
            service.submit
          end

          args = enqueued_jobs.last["arguments"].first

          expect(args).to include(
            "submission" => hash_including("_aj_globalid"),
            "notify_response_id" => email_confirmation_input.confirmation_email_reference,
            "confirmation_email_address" => copy_of_answers_email_address,
            "include_copy_of_answers" => true,
          )
        end
      end
    end
  end

  describe "#submission_locale" do
    context "when the context includes :cy in locales_used" do
      let(:locales_used) { %i[en cy] }

      it "the submission locale is decided as :cy" do
        expect(service.submission_locale).to eq(:cy)
      end
    end

    context "when the context does not include :cy in locales_used" do
      let(:locales_used) { [:en] }

      it "the submission locale is decided as :en" do
        expect(service.submission_locale).to eq(:en)
      end
    end

    context "when the context returns an empty array for locales_used" do
      let(:locales_used) { [] }

      it "the submission locale is decided as :en" do
        expect(service.submission_locale).to eq(:en)
      end
    end
  end
end
