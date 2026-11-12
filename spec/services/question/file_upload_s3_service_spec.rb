require "rails_helper"

RSpec.describe Question::FileUploadS3Service do
  subject(:service) { described_class.new }

  let(:key) { Faker::Alphanumeric.alphanumeric }
  let(:bucket) { "an-s3-bucket" }
  let(:mock_s3_client) { Aws::S3::Client.new(stub_responses: true) }

  before do
    allow(Settings.aws).to receive(:file_upload_s3_bucket_name).and_return(bucket)
    allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
    allow(Rails.logger).to receive(:info).at_least(:once)
  end

  describe "#upload_to_s3" do
    context "when a file was selected" do
      let(:tempfile) { Tempfile.new(%w[temp-file .png]) }

      after do
        tempfile.unlink
      end

      before do
        allow(mock_s3_client).to receive(:put_object)
      end

      it "puts object to S3" do
        expect(mock_s3_client).to receive(:put_object).with(
          {
            body: tempfile,
            bucket: bucket,
            key:,
          },
        )
        service.upload_to_s3(tempfile, key)
      end
    end
  end

  describe "#file_from_s3" do
    context "when the file exists in S3" do
      let(:get_object_output) { instance_double(Aws::S3::Types::GetObjectOutput) }
      let(:tempfile) { Tempfile.new(%w[temp-file .png]) }
      let(:file_content) { Faker::Lorem.sentence }

      before do
        File.write(tempfile, file_content)

        allow(mock_s3_client).to receive(:get_object).and_return(get_object_output)
        allow(get_object_output).to receive(:body).and_return(tempfile)
      end

      after do
        tempfile.unlink
      end

      it "reads file contents from S3" do
        expect(service.file_from_s3(key)).to eq(file_content)
      end

      it("logs at info level") do
        expect(Rails.logger).to receive(:info).once.with("Retrieved uploaded file from S3", {
          s3_object_key: key,
        })
        service.file_from_s3(key)
      end
    end

    context "when the file is not found in S3" do
      before do
        mock_s3_client.stub_responses(:get_object, "NoSuchKey")
      end

      it "logs at error level and re-raises the exception" do
        expect(Rails.logger).to receive(:error).once.with("Object with key does not exist in S3", {
          s3_object_key: key,
        })
        expect { service.file_from_s3(key) }.to raise_error(Aws::S3::Errors::NoSuchKey)
      end
    end
  end

  describe "#delete_from_s3" do
    before do
      allow(mock_s3_client).to receive(:delete_object)
    end

    it "calls S3 to delete the file" do
      expect(mock_s3_client).to receive(:delete_object).with(
        {
          bucket:,
          key:,
        },
      )
      service.delete_from_s3(key)
    end

    it "logs at info level" do
      expect(Rails.logger).to receive(:info).once.with("Deleted uploaded file from S3", {
        s3_object_key: key,
      })
      service.delete_from_s3(key)
    end
  end

  describe "#extend_life" do
    before do
      allow(mock_s3_client).to receive(:copy_object).with(any_args)
    end

    it "copies the file onto itself with new metadata" do
      freeze_time do
        expect(mock_s3_client).to receive(:copy_object).with(
          {
            key: key,
            bucket: bucket,
            copy_source: "#{bucket}/#{key}",
            metadata: { "extended_at" => Time.current.iso8601 },
            metadata_directive: "REPLACE",
            tagging_directive: "REPLACE",
          },
        )

        service.extend_life(key)
      end
    end

    it "logs at info level" do
      expect(Rails.logger).to receive(:info).once.with("Extended life of file in S3", {
        s3_object_key: key,
      })

      service.extend_life(key)
    end
  end

  describe "#poll_for_scan_status" do
    let(:no_threats_status) { "NO_THREATS_FOUND" }
    let(:scan_status_tagging_response) { { tag_set: [{ key: "GuardDutyMalwareScanStatus", value: no_threats_status }] } }
    let(:empty_tagging_response) { { tag_set: [] } }

    context "when the scan status tag is found on the first attempt" do
      before do
        allow(mock_s3_client).to receive(:get_object_tagging).and_return(scan_status_tagging_response)
      end

      it "calls aws once" do
        expect(mock_s3_client).to receive(:get_object_tagging).once.with(
          {
            bucket:,
            key:,
          },
        )
        service.poll_for_scan_status(key)
      end

      it "returns the scan status" do
        expect(service.poll_for_scan_status(key)).to eq(no_threats_status)
      end

      it "logs the scan status" do
        expect(Rails.logger).to receive(:info).once.with("Successfully got GuardDuty scan status for uploaded file", {
          scan_status: no_threats_status,
          scan_status_poll_attempts: 1,
          s3_object_key: key,
        })
        service.poll_for_scan_status(key)
      end
    end

    context "when the scan status is not found on the first attempt" do
      let(:first_tagging_response) { { tag_set: [] } }
      let(:second_tagging_response) { { tag_set: [{ key: "GuardDutyMalwareScanStatus", value: status }] } }
      let(:status) { "NO_THREATS_FOUND" }

      before do
        allow(mock_s3_client).to receive(:get_object_tagging).and_return(empty_tagging_response, scan_status_tagging_response)
      end

      it "calls aws 2 times" do
        expect(mock_s3_client).to receive(:get_object_tagging).twice.with(
          {
            bucket:,
            key:,
          },
        )
        service.poll_for_scan_status(key)
      end

      it "returns the scan status" do
        expect(service.poll_for_scan_status(key)).to eq(no_threats_status)
      end

      it "logs the scan status" do
        expect(Rails.logger).to receive(:info).once.with("Successfully got GuardDuty scan status for uploaded file", {
          scan_status: no_threats_status,
          scan_status_poll_attempts: 2,
          s3_object_key: key,
        })
        service.poll_for_scan_status(key)
      end
    end

    context "when scan status tag is not found after maximum attempts" do
      before do
        allow(mock_s3_client).to receive(:get_object_tagging).and_return(empty_tagging_response)
      end

      it "calls aws 2 times and raises an error" do
        expect(mock_s3_client).to receive(:get_object_tagging).twice.with(
          {
            bucket:,
            key:,
          },
        )
        expect { service.poll_for_scan_status(key) }.to raise_error(Question::FileUploadS3Service::PollForScanResultTimeoutError)
      end
    end
  end
end
