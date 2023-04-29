#!/usr/bin/env ruby

require "colorize"
require "elasticsearch"
require "slop"
require "openssl"
require "csv"

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

index = "schema"
data_file = "fields.csv"
client = nil

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
                              ECS_Version: {
                                type: "keyword"
                              },
                              Indexed: {
                                type: "boolean"
                              },
                              Field_Set: {
                                type: "keyword"
                              },
                              Field: {
                                type: "keyword"
                              },
                              Type: {
                                type: "keyword"
                              },
                              Level: {
                                type: "keyword"
                              },
                              Normalization: {
                                type: "keyword"
                              },
                              Example: {
                                type: "keyword"
                              },
                              Description: {
                                type: "text"
                              },
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
        for line in lines
          cols = line.parse_csv
          batch_for_bulk.push({ index: { _index: index } })
          batch_for_bulk.push(
            {
              ECS_Version: cols[0],
              Indexed: cols[1],
              Field_Set: cols[2],
              Field: cols[3],
              Type: cols[4],
              Level: cols[5],
              Normalization: cols[6],
              Example: cols[7],
              Description: cols[8],
            }
          )
        end
        results = client.bulk(index: index, body: batch_for_bulk)
        puts JSON.pretty_generate(results)
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
