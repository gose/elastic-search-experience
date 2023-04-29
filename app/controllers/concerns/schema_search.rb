require 'elasticsearch/dsl'

module SchemaSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def schema_search(repo, type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Field Set'] = 'Field_Set'
    filter_lookup['Level'] = 'Level'
    filter_lookup['Type'] = 'Type'

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
        aggregation :agg1 do
          terms do
            field filter_lookup['Field Set']
            size  5
          end
        end
        aggregation :agg2 do
          terms do
            field filter_lookup['Level']
            size  5
          end
        end
        aggregation :agg3 do
          terms do
            field filter_lookup['Type']
            size  5
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
                fields  ["Field", "Field_Set", "Type", "Example", "Description"]
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
          Field: {},
          Field_Set: {},
          Type: {},
          Example: {},
          Description: {}
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
      logger.debug "ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
      filters = ActiveSupport::OrderedHash.new

      # Field_Set Filter
      agg1 = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.agg1.buckets.map
        agg1[term[:key]] = term[:doc_count].to_s
      end
      filters["Field Set"] = agg1

      # success Filter
      agg2 = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.agg2.buckets.map
        agg2[term[:key]] = term[:doc_count].to_s
      end
      filters["Level"] = agg2

      # city Filter
      agg3 = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.agg3.buckets.map
        agg3[term[:key]] = term[:doc_count].to_s
      end
      filters["Type"] = agg3
    end

    return results, filters, took_ms
  end
end
