class CheckYourAnswersStep
  CHECK_YOUR_ANSWERS_STEP_SLUG = "check-your-answers".freeze

  attr_reader :next_step_slug, :step_slug, :id

  def initialize
    @id = CHECK_YOUR_ANSWERS_STEP_SLUG
    @next_step_slug = "_submit" # not used for now
    @step_slug = CHECK_YOUR_ANSWERS_STEP_SLUG
  end

  def ==(other)
    super ||
      other.class == self.class # there is only one check your answers step
  end

  def end_page?
    true
  end
end
