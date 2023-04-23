class EcommerceRepository
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

  index_name "kibana_sample_data_ecommerce"

  def deserialize(document)
    document #['_source']
  end

  def name
    'ecommerce'
  end
end
