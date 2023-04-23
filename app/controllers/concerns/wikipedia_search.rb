require 'elasticsearch/dsl'

module WikipediaSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def wikipedia_search(repo, type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Incoming Links'] = 'incoming_links'
    filter_lookup['Heading'] = 'heading'

    Elasticsearch::DSL::Search::Aggregations::Terms.option_method :collect_mode

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
        aggregation :incoming_links do
          terms do
            field        filter_lookup['Incoming Links']
            collect_mode 'breadth_first'
            size          5
          end
        end
        aggregation :heading do
          terms do
            field        filter_lookup['Heading']
            collect_mode 'breadth_first'
            size          5
          end
        end
      end
      query do
        bool do
          if type != 'quick' && filters.present?
            filter_pairs = filters.split(/--/)
            for filter_pair in filter_pairs
              key, value = filter_pair.split(/:/)
              filter do
                term "#{filter_lookup[key]}": "#{value}"
              end
            end
          end
          must do
            if query.present?
              multi_match do
                query     query
                type      "best_fields"
                fields    ["title^3", "text", "opening_text^2"]
                # fuzziness "AUTO"
              end
            else
              match_all
            end
          end
        end
      end
      if type == 'search' && query.present?
        highlight fields: {
          title: {},
          opening_text: {},
          text: {}
        }
      end
    end

    # Run the actual search, and time it.
    starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results = repo.search(definition)
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    took_ms = (ending - starting) * 1000

    # Show the query and timing
    logger.debug definition.to_json
    if took_ms < 1000
      logger.debug "Wikipedia ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "Wikipedia ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
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
