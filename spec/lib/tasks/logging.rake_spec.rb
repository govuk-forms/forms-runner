require "rails_helper"

RSpec.describe "Logging Rake Tasks", rakefile: false, type: :task do
  let(:rake) { Rake.application }
  let(:top_level_tasks) { %w[my_task] }
  let(:at_exit_handlers) { [] }

  before do
    my_task

    allow(rake).to receive(:top_level_tasks).and_return(top_level_tasks)
    allow(TOPLEVEL_BINDING.receiver).to receive(:at_exit) { |&handler| at_exit_handlers << handler }

    load Rails.root.join("lib/tasks/logging.rake")

    rake["environment"].invoke
  end

  context "when the task runs successfully" do
    let(:my_task) { Rake::Task.define_task(my_task: :environment) }

    it "logs when the task starts and finishes" do
      expect(Rails.logger).to receive(:info).with("Task started", hash_including(:args))

      expect(Rails.logger).to receive(:info).with("Task finished")

      rake["my_task"].invoke
    end

    it "logs the arguments passed in to the task" do
      expect(Rails.logger).to receive(:info).with("Task started", hash_including(args: %w[arg1 arg2]))

      allow(Rails.logger).to receive(:info).with("Task finished")

      rake["my_task"].invoke("arg1", "arg2")
    end
  end

  context "when the task is passed an email address" do
    let(:received_args) { [] }
    let(:my_task) do
      Rake::Task.define_task(:my_task, %i[email] => :environment) { |_, args| received_args << args[:email] }
    end

    it "filters the email address from the logged arguments" do
      expect(Rails.logger).to receive(:info).with("Task started", { args: ["[FILTERED]", "arg2"] })
      allow(Rails.logger).to receive(:info).with("Task finished")

      rake["my_task"].invoke("someone@example.com", "arg2")
    end

    it "passes the unfiltered email address to the task" do
      allow(Rails.logger).to receive(:info)

      rake["my_task"].invoke("someone@example.com")

      expect(received_args).to eq %w[someone@example.com]
    end
  end

  context "when the task terminates early" do
    let(:top_level_tasks) { ["my_task[someone@example.com]"] }
    let(:my_task) { Rake::Task.define_task(my_task: :environment) }

    it "filters email addresses from the logged task" do
      expect(Rails.logger).to receive(:error).with(
        "Task terminated early",
        { task: "my_task[[FILTERED]]", exit_cause: "Signal or exit" },
      )

      at_exit_handlers.each(&:call)
    end
  end

  context "when the task raises an error" do
    let(:my_task) do
      Rake::Task.define_task(my_task: :environment) do
        raise StandardError, "Something went wrong"
      end
    end

    it "logs an error with the exception" do
      allow(Rails.logger).to receive(:info).with("Task started", hash_including(:args))
      expect(Rails.logger).to receive(:error).with(
        "Task failed",
        { exception: ["StandardError", "Something went wrong"] },
      )

      expect { rake["my_task"].invoke }.to raise_error(StandardError, "Something went wrong")
    end
  end

  context "when the task is aborted with SystemExit" do
    let(:my_task) do
      Rake::Task.define_task(my_task: :environment) do
        abort "exit" # rubocop:disable Rails/Exit
      end
    end

    it "logs an error with the exit message" do
      allow(Rails.logger).to receive(:info).with("Task started", hash_including(:args))
      expect(Rails.logger).to receive(:error).with("Task aborted", { exit_message: "exit" })

      expect { rake["my_task"].invoke }
        .to raise_error(SystemExit)
        .and output(/exit/).to_stderr
    end
  end
end
