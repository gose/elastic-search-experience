#!/usr/bin/env ruby

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

index = "wikipedia"

client = nil

if parsed[:full]
  data_file =
    "/Users/gose/data/wikipedia/enwiki-20230410-cirrussearch-content.json"
else
  data_file = "/Users/gose/data/wikipedia/head.json"
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
                                type: "text",
                                fields: {
                                  keyword: {
                                    type: "keyword"
                                  },
                                  typeahead: {
                                    type: "search_as_you_type"
                                  }
                                }
                              },
                              "@timestamp": {
                                type: "date"
                              },
                              create_timestamp: {
                                type: "date"
                              },
                              incoming_links: {
                                type: "keyword"
                              },
                              category: {
                                type: "keyword"
                              },
                              text: {
                                type: "text"
                              },
                              text_bytes: {
                                type: "integer"
                              },
                              content_model: {
                                type: "keyword"
                              },
                              coordinates: {
                                type: "geo_point"
                              },
                              heading: {
                                type: "keyword"
                              },
                              opening_text: {
                                type: "text"
                              },
                              popularity_score: {
                                type: "float"
                              }
                            }
                          }
                        }
end

if parsed[:import]
  puts "Importing ..."

  File.open(data_file) do |file|
    file
      .lazy
      .each_slice(100) do |lines|
        batch_for_bulk = []
        id = nil
        for line in lines
          if line =~ /^{"index":{"_type":"_doc"/
            parsed = JSON.parse(line)
            id = parsed["index"]["_id"]
            next
          end
          parsed = JSON.parse(line)
          coordinates = nil
          if parsed["coordinates"] && parsed["coordinates"].length > 0
            coordinates = parsed["coordinates"][0]["coord"]
          end
          batch_for_bulk.push({ index: { _index: index, _id: id } })
          batch_for_bulk.push(
            {
              title: parsed["title"],
              "@timestamp": parsed["timestamp"],
              create_timestamp: parsed["create_timestamp"],
              incoming_links: parsed["incoming_links"],
              category: parsed["category"],
              text: parsed["text"],
              text_bytes: parsed["text_bytes"],
              content_model: parsed["content_model"],
              coordinates: coordinates,
              heading: parsed["heading"],
              opening_text: parsed["opening_text"],
              popularity_score: parsed["popularity_score"]
            }
          )
        end
        results = client.bulk(index: index, body: batch_for_bulk)
        # puts JSON.pretty_generate(results)
        id = nil
      end
  end
end

if parsed[:delete]
  puts "Deleting ..."
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
