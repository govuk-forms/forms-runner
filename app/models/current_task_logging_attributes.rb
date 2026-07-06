class CurrentTaskLoggingAttributes < ActiveSupport::CurrentAttributes
  attribute :task_name

  def as_hash
    {
      task_name:,
    }.compact_blank
  end
end
