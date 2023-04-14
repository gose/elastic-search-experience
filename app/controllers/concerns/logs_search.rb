require 'elasticsearch/dsl'

module LogsSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def logs_search(type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Response Code'] = 'response.keyword'
    filter_lookup['Machine OS'] = 'machine.os.keyword'
    filter_lookup['Extension'] = 'extension.keyword'

    index = LogsRepository.new

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
        aggregation :response_code do
          terms do
            field filter_lookup['Response Code']
            size  5
          end
        end
        aggregation :machine_os do
          terms do
            field filter_lookup['Machine OS']
            size  5
          end
        end
        aggregation :extension do
          terms do
            field filter_lookup['Extension']
            size  5
          end
        end
        aggregation :bytes do
          histogram do
            field    'bytes'
            interval 4096
            #hard_bounds do
              #min 100
              #max 200
            #end
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
                fields  ["message"]
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
          message: {}
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
      logger.debug "Logs ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "Logs ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
      filters = ActiveSupport::OrderedHash.new

      # response_code Filter
      response_code = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.response_code.buckets.map
        response_code[term[:key]] = term[:doc_count].to_s
      end
      filters["Response Code"] = response_code

      # machine_os Filter
      machine_os = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.machine_os.buckets.map
        machine_os[term[:key]] = term[:doc_count].to_s
      end
      filters["Machine OS"] = machine_os

      # extension Filter
      extension = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.extension.buckets.map
        extension[term[:key]] = term[:doc_count].to_s
      end
      filters["Extension"] = extension

      # bytes Filter
      bytes = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.bytes.buckets.map
        bytes[term[:key]] = term[:doc_count].to_s
      end
      filters["Bytes"] = bytes
    end

    return results, filters, took_ms
  end
end
