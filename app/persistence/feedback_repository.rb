class FeedbackRepository
  include Elasticsearch::Persistence::Repository
  include Elasticsearch::Persistence::Repository::DSL

  if Rails.env.development?
    # client Elasticsearch::Client.new url: 'http://localhost:9200'#, log: true
    client Elasticsearch::Client.new(
      user: Rails.application.credentials.dig(:elastic_cloud, :user),
      password: Rails.application.credentials.dig(:elastic_cloud, :password),
      scheme: Rails.application.credentials.dig(:elastic_cloud, :scheme),
      host: Rails.application.credentials.dig(:elastic_cloud, :host),
      port: Rails.application.credentials.dig(:elastic_cloud, :port))
  elsif Rails.env.production?
    client Elasticsearch::Client.new(
      user: Rails.application.credentials.dig(:elastic_cloud, :user),
      password: Rails.application.credentials.dig(:elastic_cloud, :password),
      scheme: Rails.application.credentials.dig(:elastic_cloud, :scheme),
      host: Rails.application.credentials.dig(:elastic_cloud, :host),
      port: Rails.application.credentials.dig(:elastic_cloud, :port))
  end

  index_name "feedback"

  settings index: {number_of_shards: 1, number_of_replicas: 1}

  mapping dynamic: 'strict' do
    indexes '@timestamp', type: 'date'
    indexes 'session_id', type: 'keyword'
    indexes 'message', type: 'text' do
      indexes 'keyword', type: 'keyword'
    end
    indexes 'email', type: 'text' do
      indexes 'keyword', type: 'keyword'
    end
  end

  def serialize(document)
    hash = {}
    hash['@timestamp'] = document[:timestamp]
    hash['session_id'] = document[:session_id]
    hash['message'] = document[:message]
    hash['email'] = document[:email]
    hash
  end

  def deserialize(document)
    document #['_source']
  end
end
