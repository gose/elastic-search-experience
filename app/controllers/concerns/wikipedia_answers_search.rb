module WikipediaAnswersSearch

  extend ActiveSupport::Concern

  def wikipedia_answers_search(repo, query, context)
    # POST _ml/trained_models/deepset__minilm-uncased-squad2/deployment/_infer
    resource = '_ml/trained_models/deepset__minilm-uncased-squad2/deployment/_infer'
    definition = <<QUERY
{
  "docs": [
    {
      "text_field": "#{context}"
    }
  ],
  "inference_config": {
    "question_answering": { "question": "#{query}" }
  }
}
QUERY

    # Run the actual search, and time it.
    starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # Ruby-Doc:
    # https://rubydoc.info/gems/elastic-transport/Elastic%2FTransport%2FClient:perform_request
    results = repo.client.perform_request('POST', resource, {timeout: '30s'}, definition)
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    took_ms = (ending - starting) * 1000

    # Show the query and timing
    logger.debug "-------------".yellow
    logger.debug "ML Answer query:".yellow
    logger.debug definition.to_json
    logger.debug "-------------".yellow
    logger.debug "ML Answer results:".yellow
    logger.debug results.body
    logger.debug "-------------".yellow
    if took_ms < 1000
      logger.debug "WikipediaAnswer ES Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "WikipediaAnswer ES Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    return results.body
    #return results, filters, took_ms
  end

end
