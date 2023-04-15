class SearchHistoryRepository
  include Elasticsearch::Persistence::Repository
  include Elasticsearch::Persistence::Repository::DSL

  if Rails.env.development?
    # client Elasticsearch::Client.new url: 'http://localhost:9200'#, log: true
    client Elasticsearch::Client.new(
             # log: true,
             transport_options: {
               ssl: {
                 ca_file: Rails.root.join("config/http_ca.crt").to_s
               }
             },
             user: Rails.application.credentials.dig(:elastic_local, :user),
             password:
               Rails.application.credentials.dig(:elastic_local, :password),
             scheme: Rails.application.credentials.dig(:elastic_local, :scheme),
             host: Rails.application.credentials.dig(:elastic_local, :host),
             port: Rails.application.credentials.dig(:elastic_local, :port)
           )
  elsif Rails.env.production?
    client Elasticsearch::Client.new(
             user: Rails.application.credentials.dig(:elastic_cloud, :user),
             password:
               Rails.application.credentials.dig(:elastic_cloud, :password),
             scheme: Rails.application.credentials.dig(:elastic_cloud, :scheme),
             host: Rails.application.credentials.dig(:elastic_cloud, :host),
             port: Rails.application.credentials.dig(:elastic_cloud, :port)
           )
  end

  index_name "search-history"

  settings index: { number_of_shards: 1, number_of_replicas: 0 }

  mapping dynamic: "strict" do
    indexes "@timestamp", type: "date"
    indexes "session_id", type: "keyword"
    indexes "user", type: "text" do
      indexes "keyword", type: "keyword"
    end
    indexes "action", type: "text" do
      indexes "keyword", type: "keyword"
    end
    indexes "index", type: "text" do
      indexes "keyword", type: "keyword"
    end
    indexes "query", type: "text" do
      indexes "keyword", type: "keyword"
    end
    indexes "filters", type: "text" do
      indexes "keyword", type: "keyword"
    end
    indexes "sort", type: "text" do
      indexes "keyword", type: "keyword"
    end
    indexes "page", type: "integer"
    indexes "took", type: "integer"
    indexes "count", type: "integer"
  end

  def serialize(document)
    hash = {}
    hash["@timestamp"] = document[:timestamp]
    hash["session_id"] = document[:session_id]
    hash["user"] = document[:user]
    hash["action"] = document[:action]
    hash["index"] = document[:index]
    hash["query"] = document[:query]
    hash["filters"] = document[:filters]
    hash["sort"] = document[:sort]
    hash["page"] = document[:page]
    hash["took"] = document[:took]
    hash["count"] = document[:count]
    hash
  end

  def deserialize(document)
    document #['_source']
  end
end
