class CheckYourAnswersStep
  CHECK_YOUR_ANSWERS_STEP_SLUG = "check-your-answers".freeze

  attr_reader :next_step_slug, :step_slug, :page_id

  def initialize
    @page_id = CHECK_YOUR_ANSWERS_STEP_SLUG
    @next_step_slug = "_submit" # not used for now
    @step_slug = CHECK_YOUR_ANSWERS_STEP_SLUG
  end

  def ==(other)
    other.class == self.class && other.state == state
  end

  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end

  def end_page?
    true
  end
end
