require "English"
require "active_support/parameter_filter"

# This block runs before the Rails app has loaded, so autoloading isn't available yet
require_relative "../../app/lib/email_parameter_filter_proc"

Rake::Task.define_task(:environment).enhance do
  task_finished_normally = false

  # Task arguments can include email addresses, which we shouldn't write to the logs
  log_filter = ActiveSupport::ParameterFilter.new([EmailParameterFilterProc.new])
  filter_for_log = ->(value) { log_filter.filter_param(nil, value) }

  at_exit do
    unless task_finished_normally
      exit_cause = $ERROR_INFO ? $ERROR_INFO.class.name : "Signal or exit"

      Rails.logger.error "Task terminated early", {
        task: filter_for_log.call(Rake.application.top_level_tasks.first),
        exit_cause:,
      }
    end
  end

  Rake.application.top_level_tasks.each do |task_name|
    task_name_clean = task_name.gsub(/\[.*\]$/, "")
    next unless Rake::Task.task_defined?(task_name_clean)

    task = Rake::Task[task_name_clean]
    original_actions = task.actions.dup
    task.actions.clear

    task.enhance do |t, args|
      CurrentTaskLoggingAttributes.task_name = task_name_clean
      Rails.logger.info "Task started", { args: args.to_a.map(&filter_for_log) }

      begin
        original_actions.each { |action| action.call(t, args) }
        Rails.logger.info "Task finished"
      rescue SystemExit => e
        Rails.logger.error "Task aborted", { exit_message: filter_for_log.call(e.message) }
        raise e
      rescue StandardError => e
        Rails.logger.error "Task failed", { exception: [e.class.name, filter_for_log.call(e.message)] }
        raise e
      ensure
        task_finished_normally = true
      end
    end
  end
end
