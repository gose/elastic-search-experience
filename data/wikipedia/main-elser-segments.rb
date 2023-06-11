#!/usr/bin/env ruby

require "colorize"
require "elasticsearch"
require "slop"
require "openssl"
require "json"

require "/Users/gose/rails/elastic/config/environment"

#
# API
#
# https://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Indices/Actions
#

$stdout.sync = true

opts = Slop::Options.new
opts.bool "-c", "--create", "Create the index"
opts.bool "-d", "--delete", "Delete the index"
opts.bool "-i", "--import", "Import the index"
opts.bool "-s", "--status", "Get cluster status"
opts.bool "-p", "--prod", "Use production cluster (default: local cluster)"
opts.bool "-f", "--full", "Full load (default: 5 docs)"
opts.int "-t", "--section", "Section", default: 1

begin
  args = opts.parse ARGV
rescue Slop::UnknownOption => e
  puts "\nError: #{e.to_s}\n\n"
  puts opts
  exit
end

if ARGV.length < 1
  puts opts
  exit
end

index = "wikipedia-elser-segments"

client = nil

if args[:full] && args[:section]
  data_file =
    "/Users/gose/data/wikipedia/enwiki-20230410-cirrussearch-content-#{args[:section]}.json.gz"
else
  #data_file = "/Users/gose/data/wikipedia/head-1000.json"
  data_file = "/Users/gose/data/wikipedia/chevy.json.gz"
end
puts "Reading:\n#{data_file}"

if args[:prod]
  client =
    Elasticsearch::Client.new(
      user: Rails.application.credentials.dig(:elastic_cloud, :user),
      password: Rails.application.credentials.dig(:elastic_cloud, :password),
      scheme: Rails.application.credentials.dig(:elastic_cloud, :scheme),
      host: Rails.application.credentials.dig(:elastic_cloud, :host),
      port: Rails.application.credentials.dig(:elastic_cloud, :port),
      request_timeout: 5 * 60 # 5 min instead of default 60 seconds
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
      port: Rails.application.credentials.dig(:elastic_local, :port),
      request_timeout: 5 * 60 # 5 min instead of default 60 seconds
    )
end

if args[:create]
  client.ingest.put_pipeline id: "elser-v1-wikipedia",
                             body: {
                               description: "Create embeddings",
                               processors: [
                                 {
                                   inference: {
                                     model_id: ".elser_model_1",
                                     target_field: "ml",
                                     field_map: {
                                       text: "text_field"
                                     },
                                     inference_config: {
                                       text_expansion: {
                                         results_field: "tokens"
                                       }
                                     }
                                   }
                                 }
                               ]
                             }
  client.indices.create index: index,
                        body: {
                          settings: {
                            number_of_shards: 2,
                            number_of_replicas: 0,
                            refresh_interval: "300s"
                          },
                          mappings: {
                            dynamic: "false",
                            properties: {
                              title: {
                                type: "text"
                              },
                              "@timestamp": {
                                type: "date"
                              },
                              text_field: {
                                type: "text"
                              },
                              "ml.tokens": {
                                type: "rank_features"
                              },
                              popularity_score: {
                                type: "float"
                              }
                            }
                          }
                        }
end

if args[:import]
  puts "Importing ..."

  found_chevy = false

  Zlib::GzipReader.open(data_file) do |file|
  # File.open(data_file) do |file|
    file
      .lazy
      .each_slice(100) do |lines|
        lines.each do |line|
          next if line =~ /^{"index":{"_type":"_doc"/
          parsed = JSON.parse(line)
          batch_for_bulk = []
          # Break up body into segments
          sentences = parsed['text'].split('.')
          sentences.map do |line|
            line.strip!
            line += ". "
          end
          segment = ''
          for line in sentences
            if line.split.count + segment.split.count < 400
              segment += " #{line}"
            else
              if parsed["title"] == 'Chevy Chase'
                found = true
              end
              batch_for_bulk.push({ index: { _index: index } })
              batch_for_bulk.push(
                {
                  title: parsed["title"],
                  "@timestamp": parsed["timestamp"],
                  text_field: segment,
                  popularity_score: parsed["popularity_score"]
                }
              )
              segment = ''
            end
          end
          if batch_for_bulk.count > 0
            if batch_for_bulk.count > 200
              puts "title: #{parsed['title']} - #{batch_for_bulk.count} segments"
            end
            results =
              client.bulk(
                index: index,
                body: batch_for_bulk,
                pipeline: "elser-v1-wikipedia"
              )
            # puts JSON.pretty_generate(results)
            exit if found
          end
        end
      end
  end
end

if args[:delete]
  puts "Deleting ..."
  client.indices.delete index: index
  client.ingest.delete_pipeline id: "elser-v1-wikipedia"
end

if args[:status]
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
