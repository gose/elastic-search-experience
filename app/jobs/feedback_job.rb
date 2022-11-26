class FeedbackJob < ApplicationJob
  queue_as :default

  def perform(feedback)
    feedback_repo = FeedbackRepository.new
    feedback_repo.save(feedback)
  end
end
