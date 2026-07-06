module Store
  module Access
    def page_key(step)
      step.id.to_s
    end
  end
end
