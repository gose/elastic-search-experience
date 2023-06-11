require 'elasticsearch/dsl'

module Elasticsearch
  module DSL
    module Search
      module Queries
        class TextExpansion
          include BaseComponent
          option_method :model_id
          option_method :model_text
        end
      end
    end
  end
end

module WikipediaELSERSegmentsSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  def wikipedia_elser_segments_search(repo, query)

    # Build the Query DSL
    definition = search do
      query do
        if query.present?
          text_expansion('ml.tokens') do
            model_id '.elser_model_1'
            model_text query
          end
        else
          match_all
        end
      end
    end

    # Run the actual search, and time it.
    starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results = repo.search(definition)
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    took_ms = (ending - starting) * 1000

    # Show the query and timing
    logger.debug "-------------".yellow
    logger.debug "ELSER Segment ES query:".yellow
    logger.debug definition.to_json
    logger.debug "-------------".yellow
    logger.debug "ELSER Segment ES results:".yellow
    logger.debug results.count
    logger.debug "-------------".yellow
    if took_ms < 100
      logger.debug "WikipediaELSER Segment ES Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "WikipediaELSER Segment ES Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    return results
  end

end
