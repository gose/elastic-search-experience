require 'elasticsearch/dsl'
require 'json'
include Elasticsearch::DSL

module Elasticsearch
  module DSL
    module Search
      module Queries
        class TextExpansion
          include BaseComponent

          option_method :model_id
          option_method :model_text
        end
      end
    end
  end
end

query = search do
  query do
    text_expansion('ml.tokens') do
      model_id 'test'
      model_text 'test'
    end
  end
end

puts JSON.pretty_generate(query.to_hash)