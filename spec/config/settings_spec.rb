# frozen_string_literal: true

require "rails_helper"

describe "Settings" do
  settings = YAML.load_file(Rails.root.join("config/settings.yml")).with_indifferent_access
  expected_value_test = "expected_value_test"

  shared_examples expected_value_test do |key, source, expected_value|
    describe ".#{key}" do
      subject do
        source[key]
      end

      it "#{key} has a default value" do
        expect(subject).to eq(expected_value)
      end
    end
  end

  describe ".features" do
    it "has a default value" do
      features = settings[:features]

      expect(features).to eq({ "dummy" => false, "filler_answer_email_enabled" => false })
    end
  end

  describe ".forms_api" do
    forms_api = settings[:forms_api]

    include_examples expected_value_test, :base_url, forms_api, "http://localhost:3000"
  end

  describe ".forms_product_page" do
    forms_product_page = settings[:forms_product_page]

    include_examples expected_value_test, :base_url, forms_product_page, "http://localhost:3002"
  end

  describe ".govuk_notify" do
    govuk_notify = settings[:govuk_notify]

    include_examples expected_value_test, :api_key, govuk_notify, "changeme"
    include_examples expected_value_test, :form_submission_email_reply_to_id, govuk_notify, "fab9373b-fb7c-483f-ae25-5a9852bfcc04"
    include_examples expected_value_test, :form_submission_email_template_id, govuk_notify, "427eb8bc-ce0d-40a3-bf54-d76e8c3ec916"
    include_examples expected_value_test, :form_filler_confirmation_email_template_id, govuk_notify, "2d1f36dc-9799-43dd-8673-b631f9e0b4a5"
    include_examples expected_value_test, :form_filler_confirmation_email_welsh_template_id, govuk_notify, "b297c8f1-419e-4af4-b067-b8cad6364daf"
  end

  describe "sentry" do
    sentry = settings[:sentry]

    include_examples expected_value_test, :dsn, sentry, nil

    include_examples expected_value_test, :environment, sentry, "local"
  end

  describe "maintenance_mode" do
    maintenance_mode = settings[:maintenance_mode]

    include_examples expected_value_test, :enabled, maintenance_mode, false
    include_examples expected_value_test, :bypass_ips, maintenance_mode, nil
  end

  describe "forms_env" do
    it "has a default value" do
      forms_env = settings[:forms_env]

      expect(forms_env).to eq("local")
    end
  end

  describe "cloudwatch_metrics_enabled" do
    it "has a default value" do
      cloudwatch_metrics_enabled = settings[:cloudwatch_metrics_enabled]

      expect(cloudwatch_metrics_enabled).to be(false)
    end
  end

  describe "analytics_enabled" do
    it "has a default value" do
      analytics_enabled = settings[:analytics_enabled]

      expect(analytics_enabled).to be(false)
    end
  end
end
