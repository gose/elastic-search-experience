class LogSearchRequestJob < ApplicationJob
  queue_as :default

  def perform(search_history)
    search_history_repo = SearchHistoryRepository.new
    search_history_repo.save(search_history)
  end
end
