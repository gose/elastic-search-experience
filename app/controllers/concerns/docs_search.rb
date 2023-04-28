require 'elasticsearch/dsl'

module DocsSearch

  extend ActiveSupport::Concern
  include Elasticsearch::DSL

  # type = quick, search, facet
  def docs_search(repo, type, query, filters, page, sort)

    filter_lookup = {}
    filter_lookup['Category'] = 'category'
    filter_lookup['Section'] = 'section'

    # Build the Query DSL
    definition = search do
      if type == 'facet'
        size 0
        aggregation :category do
          terms do
            field filter_lookup['Category']
            size  10
          end
        end
        aggregation :section do
          terms do
            field filter_lookup['Section']
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
                fields  ["title", "content"]
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
          content: {}
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
      logger.debug "Elastic Docs ES #{type.titleize} Query: " +
        "#{sprintf("%0.0f", took_ms)} ms 🚀".light_green
    else
      logger.debug "Elastic Docs ES #{type.titleize} Query: " +
        "#{sprintf("%0.1f", took_ms / 1000 )} seconds 🐢".light_red
    end

    if type == 'facet'
      filters = ActiveSupport::OrderedHash.new

      # category Filter
      category = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.category.buckets.map
        category[term[:key]] = term[:doc_count].to_s
      end
      filters["Category"] = category

      # section Filter
      section = ActiveSupport::OrderedHash.new
      for term in results.response.aggregations.section.buckets.map
        section[term[:key]] = term[:doc_count].to_s
      end
      filters["Section"] = section
    end

    return results, filters, took_ms
  end
end
