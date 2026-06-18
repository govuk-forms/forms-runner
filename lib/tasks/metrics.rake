namespace :metrics do
  desc "Export submission counts for the last 5 minutes as OpenTelemetry metrics grouped by form"
  task export_submission_counts: :environment do
    Metrics::SubmissionCountService.new.publish_submission_counts
  end
end
