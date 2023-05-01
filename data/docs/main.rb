#!/usr/bin/env ruby

require "date"
require "colorize"
require "elasticsearch"
require "slop"
require "openssl"
require "json"

require "/Users/gose/rails/elastic-sample/config/environment"

#
# API
#
# https://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Indices/Actions
#

opts = Slop::Options.new
opts.bool "-c", "--create", "Create the index"
opts.bool "-d", "--delete", "Delete the index"
opts.bool "-i", "--import", "Import the index"
opts.bool "-s", "--status", "Get cluster status"
opts.bool "-p", "--prod", "Use production cluster (default: local cluster)"
opts.bool "-f", "--full", "Full load (default: 5 docs)"

begin
  parsed = opts.parse ARGV
rescue Slop::UnknownOption => e
  puts "\nError: #{e.to_s}\n\n"
  puts opts
  exit
end

if ARGV.length < 1
  puts opts
  exit
end

index = "docs"

client = nil

if parsed[:full]
  data_file = nil
else
  data_file = nil
end

if parsed[:prod]
  client =
    Elasticsearch::Client.new(
      user: Rails.application.credentials.dig(:elastic_cloud, :user),
      password: Rails.application.credentials.dig(:elastic_cloud, :password),
      scheme: Rails.application.credentials.dig(:elastic_cloud, :scheme),
      host: Rails.application.credentials.dig(:elastic_cloud, :host),
      port: Rails.application.credentials.dig(:elastic_cloud, :port)
    )
else
  client =
    Elasticsearch::Client.new(
      log: true,
      transport_options: {
        ssl: {
          ca_file: Rails.root.join("config/http_ca.crt").to_s
        }
      },
      user: Rails.application.credentials.dig(:elastic_local, :user),
      password: Rails.application.credentials.dig(:elastic_local, :password),
      scheme: Rails.application.credentials.dig(:elastic_local, :scheme),
      host: Rails.application.credentials.dig(:elastic_local, :host),
      port: Rails.application.credentials.dig(:elastic_local, :port)
    )
end

if parsed[:create]
  puts "Creating index ..."
  client.indices.create index: index,
                        body: {
                          settings: {
                            number_of_shards: 1,
                            number_of_replicas: 0,
                            refresh_interval: "10s"
                          },
                          mappings: {
                            dynamic: "strict",
                            properties: {
                              title: {
                                type: "text"
                              },
                              timestamp: {
                                type: "date"
                              },
                              language: {
                                type: "keyword"
                              },
                              category: {
                                type: "keyword"
                              },
                              section: {
                                type: "keyword"
                              },
                              version: {
                                type: "keyword"
                              },
                              url: {
                                type: "keyword"
                              },
                              content: {
                                type: "text"
                              }
                            }
                          }
                        }
end

def ingest(client, index, dir, cat, sec, ver)
  docs = []

  Dir[dir].each do |file|
    if file =~ /toc\.html$/
      puts "Skipping: " + file
      next
    end
    doc = `w3m -dump #{file}`
    title = ""
    content = ""
    found_title = false
    found_content = false
    prev_line = ""
    prev_prev_line = ""
    for line in doc.split(/\n/)
      if line =~ /»$/ && !found_content
        # elasticsearch/client/nest-api has a weird header that triggers this prematurely
        # so we protect against it
        if line !~ /NEST/
          found_content = true
          content = ""
        end
      elsif (line =~ /»$/ || line =~ /^Most Popular$/) && found_content
        # We have reached the end of the good content
        break
      elsif (line =~ /edit.*$/ || line =~ /━━━━━━━━━━/) && !found_title
        found_title = true
        if line =~ /━━━━━━━━━━/
          title = prev_prev_line
        else
          title = line.gsub(/edit.*$/, "")
        end
      else
        scrubbed_line = line.gsub(/edit$/, "")
        # w3m draws ascii tables, remove them.
        scrubbed_line.gsub!(/─/, "")
        scrubbed_line.gsub!(/│/, "")
        scrubbed_line.gsub!(/┬/, "")
        scrubbed_line.gsub!(/┼/, "")
        scrubbed_line.gsub!(/┴/, "")
        scrubbed_line.gsub!(/├/, "")
        scrubbed_line.gsub!(/┤/, "")
        scrubbed_line.gsub!(/┌/, "")
        scrubbed_line.gsub!(/┐/, "")
        scrubbed_line.gsub!(/└/, "")
        scrubbed_line.gsub!(/┘/, "")
        # replace w3m bullet with better bullet
        scrubbed_line.gsub!(/□/, "•")
        # remove any extra whitespace
        scrubbed_line.gsub!(/\s+/, " ")
        content += " " + scrubbed_line
      end
      prev_prev_line = prev_line
      prev_line = line
    end
    url = "https://www.elastic.co/guide/"
    url += file.split(%r{built-docs/html/})[1]
    docs << {
      title: "#{title}",
      timestamp: "#{DateTime.now.to_s}",
      language: "en",
      category: "#{cat}",
      section: "#{sec}",
      version: "#{ver}",
      url: "#{url}",
      content: "#{content}"
    }
  end

  batch_for_bulk = []

  for doc in docs
    batch_for_bulk.push({ index: { _index: index } })
    batch_for_bulk.push(
      {
        title: doc[:title],
        timestamp: doc[:timestamp],
        language: doc[:language],
        category: doc[:category],
        section: doc[:section],
        version: doc[:version],
        url: doc[:url],
        content: doc[:content]
      }
    )
    if batch_for_bulk.count == 200
      results = client.bulk(index: index, body: batch_for_bulk)
      # puts JSON.pretty_generate(results)
      batch_for_bulk = []
    end
  end

  # Flush the remaining
  results = client.bulk(index: index, body: batch_for_bulk)
  # puts JSON.pretty_generate(results)
end

if parsed[:import]
  puts "Importing documents ..."
  clean_names = {}

  clean_names["community"] = "Community"
  clean_names["go-api"] = "Go Client"
  clean_names["java-api"] = "Java Client"
  clean_names["net-api"] = ".NET Client"
  clean_names["python-api"] = "Python Client"
  clean_names["curator"] = "Curator"
  clean_names["groovy-api"] = "Groovy Client"
  clean_names["java-rest"] = "Java REST Client"

  # Elasticsearch Clients
  for sec in %w[
    community
    go-api
    java-api
    net-api
    python-api
    curator
    groovy-api
    java-rest
    perl-api
    ruby-api
    eland
    javascript-api
    php-api
    rust-api
  ]
    ingest(
      client,
      index,
      "/home/gose/data/built-docs/html/en/elasticsearch/client/#{sec}/current/*.html",
      "Elasticsearch",
      "#{clean_names[sec]}",
      "current"
    )
  end

  # Elasticsearch (remainder of sections)
  for sec in %w[guide hadoop painless plugins reference resiliency]
    ingest(
      client,
      index,
      "/home/gose/data/built-docs/html/en/elasticsearch/#{sec}/current/*.html",
      "Elasticsearch",
      "#{sec.capitalize}",
      "current"
    )
  end

  clean_names = {}
  clean_names["kibana"] = "Kibana"
  clean_names["app-search"] = "App Search"
  clean_names["cloud-enterprise"] = "Cloud Enterprise"
  clean_names["cloud-heroku"] = "Cloud Heroku"
  clean_names["cloud-on-k8s"] = "Cloud on K8s"
  clean_names["cloud"] = "Cloud"
  clean_names["ecctl"] = "Ecctl"
  clean_names["ecs"] = "ECS"
  clean_names["elastic-stack-deploy"] = "Stack Deploy"
  clean_names["elastic-stack-get-started"] = "Getting Started"
  clean_names["elastic-stack-gke"] = "GKE"
  clean_names["elastic-stack-glossary"] = "Stack Glossary"
  clean_names["elastic-stack-overview"] = "Stack Overview"
  clean_names["elastic-stack"] = "Stack"
  clean_names["endpoint"] = "Endpoint"
  clean_names["enterprise-search"] = "Enterprise Search"
  clean_names["fleet"] = "Fleet"
  clean_names["graph"] = "Graph"
  clean_names["ingest-management"] = "Ingest Management"
  clean_names["logstash"] = "Logstash"
  clean_names["machine-learning"] = "Machine Learning"
  clean_names["marvel"] = "Marvel"
  clean_names["observability"] = "Observability"
  clean_names["reporting"] = "Reporting"
  clean_names["security"] = "Security"
  clean_names["sense"] = "Sense"
  clean_names["shield"] = "Shield"
  clean_names["uptime"] = "Uptime"
  clean_names["watcher"] = "Watcher"
  clean_names["workplace-search"] = "Workplace Search"
  clean_names["x-pack"] = "X-Pack"

  # Single directory Categories, w/ no Sections
  for sec in %w[
    kibana
    app-search
    cloud-enterprise
    cloud-heroku
    cloud-on-k8s
    cloud
    ecctl
    ecs
    elastic-stack-deploy
    elastic-stack-get-started
    elastic-stack-gke
    elastic-stack-glossary
    elastic-stack-overview
    elastic-stack
    endpoint
    enterprise-search
    machine-learning
    marvel
    observability
    reporting
    security
    sense
    shield
    uptime
    watcher
    workplace-search
    x-pack
  ]
    ingest(
      client,
      index,
      "/home/gose/data/built-docs/html/en/#{sec}/current/*.html",
      "#{clean_names[sec]}",
      "",
      "current"
    )
  end

  clean_names["auditbeat"] = "Auditbeat"
  clean_names["filebeat"] = "Filebeat"
  clean_names["heartbeat"] = "Heartbeat"
  clean_names["libbeat"] = "libbeat"
  clean_names["metricbeat"] = "Metricbeat"
  clean_names["topbeat"] = "Topbeat"
  clean_names["devguide"] = "Dev Guide"
  clean_names["functionbeat"] = "Functionbeat"
  clean_names["journalbeat"] = "Journalbeat"
  clean_names["loggingplugin"] = "Logging Plugin"
  clean_names["packetbeat"] = "Packetbeat"
  clean_names["winlogbeat"] = "Winlogbeat"

  # Beats
  for sec in %w[
    auditbeat
    filebeat
    heartbeat
    libbeat
    metricbeat
    topbeat
    devguide
    functionbeat
    journalbeat
    loggingplugin
    packetbeat
    winlogbeat
  ]
    ingest(
      client,
      index,
      "/home/gose/data/built-docs/html/en/beats/#{sec}/current/*.html",
      "Beats",
      "#{clean_names[sec]}",
      "current"
    )
  end

  # Infrastructure
  ingest(
    client,
    index,
    "/home/gose/data/built-docs/html/en/infrastructure/guide/current/*.html",
    "Infrastructure",
    "",
    "current"
  )

  # Logs
  ingest(
    client,
    index,
    "/home/gose/data/built-docs/html/en/logs/guide/current/*.html",
    "Logs",
    "",
    "current"
  )

  # Metrics
  ingest(
    client,
    index,
    "/home/gose/data/built-docs/html/en/metrics/guide/current/*.html",
    "Metrics",
    "",
    "current"
  )

  # SIEM
  ingest(
    client,
    index,
    "/home/gose/data/built-docs/html/en/siem/guide/current/*.html",
    "SIEM",
    "",
    "current"
  )

  clean_names["appsearch"] = "App Search"
  clean_names["sitesearch"] = "Site Search"

  # Swiftype
  for sec in %w[appsearch sitesearch]
    ingest(
      client,
      index,
      "/home/gose/data/built-docs/html/en/swiftype/#{sec}/current/*.html",
      "Swiftype",
      "#{clean_names[sec]}",
      "current"
    )
  end

  clean_names["get-started"] = "Getting Started"
  clean_names["server"] = "APM Server"

  # APM
  for sec in %w[get-started server]
    ingest(
      client,
      index,
      "/home/gose/data/built-docs/html/en/apm/#{sec}/current/*.html",
      "APM",
      "#{clean_names[sec]}",
      "current"
    )
  end

  clean_names["dotnet"] = ".NET APM"
  clean_names["go"] = "Go APM"
  clean_names["java"] = "Java APM"
  clean_names["nodejs"] = "Node APM"
  clean_names["php"] = "PHP APM"
  clean_names["python"] = "Python APM"
  clean_names["ruby"] = "Ruby APM"
  clean_names["rum-js"] = "RUM APM"

  # APM Agents
  for sec in %w[dotnet go java nodejs php python ruby rum-js]
    ingest(
      client,
      index,
      "/home/gose/data/built-docs/html/en/apm/agent/#{sec}/current/*.html",
      "APM",
      "#{clean_names[sec]}",
      "current"
    )
  end
end

if parsed[:delete]
  puts "Deleting index ..."
  client.indices.delete index: index
end

if parsed[:status]
  print "\nGetting cluster status ... "
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  health = client.cluster.health
  finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  diff = finish - start # gets time is seconds as a float
  if health["status"] == "green"
    puts "green".light_green
    puts "Took #{"%0.4f" % diff} ms"
  elsif health["status"] == "yellow"
    puts "yellow".light_yellow
    puts "Took #{"%0.4f" % diff} ms"
  elsif health["status"] == "red"
    puts "red".light_red
    puts "Took #{"%0.4f" % diff} ms"
  end
  puts
end
