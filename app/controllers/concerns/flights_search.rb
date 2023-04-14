require 'elasticsearch/dsl'

module FlightsSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def flights_search(type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Date'] = 'scheduled_departure_time'
    filter_lookup['Airline'] = 'carrier'
    filter_lookup['Origin'] = 'origin'
    filter_lookup['Destination'] = 'destination'
    filter_lookup['Tail'] = 'tail'
    filter_lookup['Air Time'] = 'air_time_min'

    index = FlightsRepository.new

    # Elasticsearch::DSL::Search::Aggregations::DateHistogram.option_method :calendar_interval

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
        aggregation :date do
          date_histogram do
            field    filter_lookup['Date']
            interval '1y'
          end
        end
        aggregation :airline do
          terms do
            field filter_lookup['Airline']
            size  5
          end
        end
        aggregation :origin do
          terms do
            field filter_lookup['Origin']
            size  5
          end
        end
        aggregation :destination do
          terms do
            field filter_lookup['Destination']
            size  5
          end
        end
        aggregation :tail do
          terms do
            field filter_lookup['Tail']
            size  5
          end
        end
        aggregation :air_time do
          histogram do
            field    filter_lookup['Air Time']
            interval 60
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
                fields  ["airline", "carrier", "tail", "number", "origin_city", "destination_city", "origin", "destination", "origin_name", "destination_name"]
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
          airline: {},
          carrier: {},
          tail: {},
          number: {},
          origin: {},
          destination: {},
          origin_city: {},
          destination_city: {},
          origin_name: {},
          destination_name: {}
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
      logger.debug "Flights ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "Flights ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
      filters = ActiveSupport::OrderedHash.new

      # date Filter
      date = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.date.buckets.map
        date[Time.at(term[:key] / 1000).strftime("%Y")] = term[:doc_count]
      end
      filters["Date"] = date

      # airline Filter
      airline = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.airline.buckets.map
        airline[term[:key]] = term[:doc_count].to_s
      end
      filters["Airline"] = airline

      # origin Filter
      origin = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.origin.buckets.map
        origin[term[:key]] = term[:doc_count].to_s
      end
      filters["Origin"] = origin

      # destination Filter
      destination = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.destination.buckets.map
        destination[term[:key]] = term[:doc_count].to_s
      end
      filters["Destination"] = destination

      # tail Filter
      tail = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.tail.buckets.map
        tail[term[:key]] = term[:doc_count].to_s
      end
      filters["Tail"] = tail

      # air_time Filter
      air_time = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.air_time.buckets.map
        air_time[term[:key]] = term[:doc_count].to_s
      end
      filters["Air Time"] = air_time
    end

    return results, filters, took_ms
  end
end
