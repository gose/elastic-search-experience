require 'elasticsearch/dsl'

module EcommerceOrders

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def ecommerce_orders_search(type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Currency'] = 'currency'
    filter_lookup['Day of Week'] = 'day_of_week'
    filter_lookup['Manufacturer'] = 'manufacturer'
    filter_lookup['Type'] = 'type.keyword'
    filter_lookup['City'] = 'city'
    filter_lookup['Region'] = 'region'
    filter_lookup['Country'] = 'country'

    index = EcommerceOrdersRepository.new

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
=begin
        aggregation :amount_100 do
          histogram do
            field     filter_lookup['Amount']
            interval  100
          end
        end
        aggregation :amount_1000 do
          histogram do
            field     filter_lookup['Amount']
            interval  1000
          end
        end
        aggregation :amount_10000 do
          histogram do
            field     filter_lookup['Amount']
            interval  10000
          end
        end
=end
        aggregation :operation do
          terms do
            field filter_lookup['Currency']
            size  5
          end
        end
        aggregation :success do
          terms do
            field filter_lookup['Day of Week']
            size  7
          end
        end
        aggregation :city do
          terms do
            field filter_lookup['City']
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
                # type    "best_fields"
                # fields  ["atm_location", "atm_city", "customer_first_name", "customer_last_name", "customer_phone"]
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
          atm_location: {},
          atm_city: {},
          customer_first_name: {},
          customer_last_name: {},
          customer_phone: {}
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
      logger.debug "Ecommerce Orders ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "Ecommerce Orders ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
      filters = ActiveSupport::OrderedHash.new

=begin
      # amount_10000 Filter
      amount_10000 = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.amount_10000.buckets.map
        amount_10000[term[:key]] = term[:doc_count].to_s
      end
      filters["Amount_10000"] = amount_10000

      # amount_1000 Filter
      amount_1000 = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.amount_1000.buckets.map
        amount_1000[term[:key]] = term[:doc_count].to_s
      end
      filters["Amount_1000"] = amount_1000

      # amount_100 Filter
      amount_100 = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.amount_100.buckets.map
        amount_100[term[:key]] = term[:doc_count].to_s
      end
      filters["Amount_100"] = amount_100
=end
      # operation Filter
      operation = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.operation.buckets.map
        operation[term[:key]] = term[:doc_count].to_s
      end
      filters["Operation"] = operation

      # success Filter
      success = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.success.buckets.map
        if term[:key] == "0"
          success[:false] = term[:doc_count].to_s
        else
          success[:true] = term[:doc_count].to_s
        end
      end
      filters["Success"] = success

      # city Filter
      city = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.city.buckets.map
        city[term[:key]] = term[:doc_count].to_s
      end
      filters["City"] = city

      # network Filter
      network = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.network.buckets.map
        network[term[:key]] = term[:doc_count].to_s
      end
      filters["Network"] = network

      # plan Filter
      plan = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.plan.buckets.map
        plan[term[:key]] = term[:doc_count].to_s
      end
      filters["Plan"] = plan

      # card_type Filter
      card_type = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.card_type.buckets.map
        card_type[term[:key]] = term[:doc_count].to_s
      end
      filters["Card Type"] = card_type
    end

    return results, filters, took_ms
  end
end
