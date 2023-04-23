require 'elasticsearch/dsl'

module LunchSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def lunch_search(repo, type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Availability'] = 'availability.keyword'
    filter_lookup['Category'] = 'category.keyword'
    filter_lookup['Cuisine'] = 'cuisine_name.keyword'
    filter_lookup['Diet'] = 'diet.keyword'
    filter_lookup['Price'] = 'price'

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
        aggregation :availability do
          terms do
            field filter_lookup['Availability']
            size  7
          end
        end
        aggregation :category do
          terms do
            field filter_lookup['Category']
            size  5
          end
        end
        aggregation :cuisine do
          terms do
            field filter_lookup['Cuisine']
            size  5
          end
        end
        aggregation :diet do
          terms do
            field filter_lookup['Diet']
            size  5
          end
        end
        aggregation :price do
          histogram do
            field     filter_lookup['Price']
            interval  5
          end
        end
      end
      query do
        bool do
          if type != 'quick' && filters.present?
            filter_pairs = filters.split(/--/)
            for field_pair in filter_pairs
              key, value = field_pair.split(/:/)
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
                # fields  ["name", "description", "availablity", "category", "cuisine", "diet"]
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
          description: {},
          availability: {},
          cuisine: {},
          category: {},
          diet: {}
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
      logger.debug "Lunch ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "Lunch ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
      filters = ActiveSupport::OrderedHash.new

      # availability Filter
      availability = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.availability.buckets.map
        availability[term[:key]] = term[:doc_count].to_s
      end
      filters["Availability"] = availability

      # category Filter
      category = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.category.buckets.map
        category[term[:key]] = term[:doc_count].to_s
      end
      filters["Category"] = category

      # cuisine Filter
      cuisine = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.cuisine.buckets.map
        cuisine[term[:key]] = term[:doc_count].to_s
      end
      filters["Cuisine"] = cuisine

      # diet Filter
      diet = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.diet.buckets.map
        diet[term[:key]] = term[:doc_count].to_s
      end
      filters["Diet"] = diet

      # price Filter
      price = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.price.buckets.map
        price[term[:key]] = term[:doc_count].to_s
      end
      filters["Price"] = price
    end

    return results, filters, took_ms
  end

end
