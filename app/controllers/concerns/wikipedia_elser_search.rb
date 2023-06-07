module WikipediaELSERSearch
  extend ActiveSupport::Concern

  # type = quick, search, facet
  def wikipedia_elser_search(repo, type, query, filters, page, sort)
    filter_lookup = {}
    filter_lookup["Incoming Links"] = "incoming_links"
    filter_lookup["Heading"] = "heading"

    if type == "search"
      definition = <<QUERY
{
  "query": {
    "bool": {
      "must": [
        {
          "text_expansion": {
            "ml.tokens": {
              "model_id": ".elser_model_1",
              "model_text": "#{query}"
            }
          }
        }
      ]
    }
  },
  "highlight": {
    "fields": {
      "title": {},
      "opening_text": {},
      "text_field": {}
    }
  }
}
QUERY
    elsif type == "facet"
      definition = <<QUERY
{
  "query": {
    "bool": {
      "must": [
        {
          "text_expansion": {
            "ml.tokens": {
              "model_id": ".elser_model_1",
              "model_text": "#{query}"
            }
          }
        }
      ]
    }
  },
  "aggregations": {
    "incoming_links": {
      "terms": {
        "field": "incoming_links",
        "collect_mode": "breadth_first",
        "size": 5
      }
    },
    "heading": {
      "terms": {
        "field": "heading",
        "collect_mode": "breadth_first",
        "size": 5
      }
    }
  },
  "size": 0
}
QUERY
    elsif type == "quick"
      definition = <<QUERY
{
  "query": {
    "bool": {
      "must": [
        {
          "text_expansion": {
            "ml.tokens": {
              "model_id": ".elser_model_1",
              "model_text": "#{query}"
            }
          }
        }
      ]
    }
  }
}
QUERY
    end

    # Convert the JSON string to JSON
    definition = JSON.parse(definition)

    # Run the actual search, and time it.
    starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results = repo.search(definition)
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    took_ms = (ending - starting) * 1000

    # Show the query and timing
    logger.debug "-------------".yellow
    logger.debug "#{type} query:".yellow
    logger.debug definition.to_json
    logger.debug "-------------".yellow
    logger.debug "results:".yellow
    logger.debug results.count
    logger.debug "-------------".yellow
    if took_ms < 1000
      logger.debug "WikipediaELSER ES #{type.titleize} Query: " +
                     "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "Wikipedia ES #{type.titleize} Query: " +
                     "#{sprintf("%0.1f", took_ms / 1000)} seconds 🐢".light_red
    end

    if type == "facet"
      filters = ActiveSupport::OrderedHash.new

      # Heading Filter
      heading = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.heading.buckets.map
        heading[term[:key]] = term[:doc_count].to_s
      end
      filters["Heading"] = heading

      # Incoming Links Filter
      incoming_links = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.incoming_links.buckets.map
        incoming_links[term[:key]] = term[:doc_count].to_s
      end
      filters["Incoming Links"] = incoming_links
    end

    return results, filters, took_ms
  end
end
