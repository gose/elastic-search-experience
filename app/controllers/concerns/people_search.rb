require 'elasticsearch/dsl'

module PeopleSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def people_search(type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Location'] = 'location.keyword'
    filter_lookup['Title'] = 'title.keyword'

    index = PeopleRepository.new

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
        aggregation :title do
          terms do
            field 'title.keyword'
            size  5
          end
        end
        aggregation :location do
          terms do
            field 'location.keyword'
            size  10
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
                query   query
                type    "best_fields"
                fields  ["name", "title", "location"]
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
          name: {},
          title: {},
          location: {}
        }
      end
    end

    # Run the actual search, and time it.
    starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results = index.search(definition)
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    took_ms = (ending - starting) * 1000

    # Show the query and timing
    logger.debug definition.to_json
    if took_ms < 1000
      logger.debug "People ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "People ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
      filters = ActiveSupport::OrderedHash.new

      # Location Filter
      location = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.location.buckets.map
        location[term[:key]] = term[:doc_count].to_s
      end
      filters["Location"] = location

      # Title Filter
      title = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.title.buckets.map
        title[term[:key]] = term[:doc_count].to_s
      end
      filters["Title"] = title
    end

    return results, filters, took_ms
  end
end
