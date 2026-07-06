require "rails_helper"

RSpec.describe ApplicationController do
  controller do
    rescue_from RuntimeError do |e|
      log_rescued_exception(e)
      render "errors/internal_server_error", status: :internal_server_error
    end

    def raise_error
      raise "oh no\nwhat happened"
    end

    def raise_error_with_cause
      raise "inner error"
    rescue RuntimeError
      raise "outer error"
    end
  end

  before do
    routes.draw do
      get "raise_error" => "anonymous#raise_error"
      get "raise_error_with_cause" => "anonymous#raise_error_with_cause"
    end
  end

  specify "anonymous controller" do
    get :raise_error
    expect(response).to have_http_status :internal_server_error
  end

  describe "adding exception to logging context", :capture_logging do
    it "adds rescued exception to logging context" do
      get :raise_error

      expect(log_lines.last["rescued_exception"]).to eq(["RuntimeError", "oh no\nwhat happened"])
    end

    it "adds exception trace to logging context" do
      get :raise_error

      expect(log_lines.last.keys).to include("rescued_exception_trace")
      expect(log_lines.last["rescued_exception_trace"]).to include(
        "spec/controllers/application_controller_spec.rb:11:in 'raise_error'",
      )
    end

    it "adds exception causes to logging context" do
      get :raise_error_with_cause

      expect(log_lines.last.keys).to include("rescued_exception_trace")
      expect(log_lines.last["rescued_exception_trace"]).to include(
        "\nCauses:",
        "RuntimeError (inner error)",
      )
    end
  end

  describe "logging exception", :capture_logging do
    it "logs rescued exceptions as warnings" do
      get :raise_error

      expect(log_line)
        .to include("level" => "WARN",
                    "message" => a_string_including("Rescued exception:\n  \nRuntimeError (oh no\nwhat happened)"))
    end

    it "logs causes of rescued exceptions" do
      get :raise_error_with_cause

      expect(log_line)
        .to include("level" => "WARN",
                    "message" => a_string_including("RuntimeError (outer error):\n\nCauses:\nRuntimeError (inner error)"))
    end
  end

  describe "sending exception to Sentry" do
    before do
      allow(Sentry).to receive(:capture_exception)
    end

    it "captures the exception" do
      get :raise_error

      expect(Sentry).to have_received(:capture_exception)
    end
  end
end
