#!/usr/bin/env ruby

require "colorize"
require "elasticsearch"
require "slop"
require "openssl"

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
opts.bool "-f", "--full", "Full load (default: 10 docs)"

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

index = "atm"

client = nil

if parsed[:full]
  data_file = "/Users/gose/data/atm/atm.csv"
else
  data_file = "/Users/gose/data/atm/head.csv"
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
                            number_of_shards: 2,
                            number_of_replicas: 0,
                            refresh_interval: "10s"
                          },
                          mappings: {
                            dynamic: "strict",
                            properties: {
                              "@timestamp": {
                                type: "date"
                              },
                              atm_cross_streets: {
                                type: "keyword"
                              },
                              "atm_city": {
                                type: "keyword"
                              },
                              atm_location: {
                                type: "geo_point"
                              },
                              atm_serial_no: {
                                type: "keyword"
                              },
                              atm_id: {
                                type: "keyword"
                              },
                              atm_network: {
                                type: "keyword"
                              },
                              customer_salutation: {
                                type: "keyword"
                              },
                              customer_first_name: {
                                type: "keyword"
                              },
                              customer_last_name: {
                                type: "keyword"
                              },
                              customer_soc_sec: {
                                type: "keyword"
                              },
                              customer_address: {
                                type: "keyword"
                              },
                              customer_city: {
                                type: "keyword"
                              },
                              customer_state: {
                                type: "keyword"
                              },
                              customer_state_abbr: {
                                type: "keyword"
                              },
                              customer_zip: {
                                type: "keyword"
                              },
                              customer_location: {
                                type: "geo_point"
                              },
                              customer_phone: {
                                type: "keyword"
                              },
                              customer_plan: {
                                type: "keyword"
                              },
                              card_number: {
                                type: "keyword"
                              },
                              card_last_four: {
                                type: "keyword"
                              },
                              card_expiration_date: {
                                type: "keyword"
                              },
                              card_type: {
                                type: "keyword"
                              },
                              amount: {
                                type: "float"
                              },
                              operation: {
                                type: "keyword"
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
          cols = line.split('||')
          batch_for_bulk.push({ index: { _index: index } })
          batch_for_bulk.push(
            {
              "@timestamp": cols[0],
              atm_cross_streets: cols[1],
              atm_city: cols[2],
              atm_location: {"lat":cols[3], "lon":cols[4]},
              atm_serial_no: cols[5],
              atm_id: cols[6],
              atm_network: cols[7],
              customer_salutation: cols[8],
              customer_first_name: cols[9],
              customer_last_name: cols[10],
              customer_soc_sec: cols[17],
              customer_address: cols[18],
              customer_city: cols[19],
              customer_state: cols[20],
              customer_state_abbr: cols[21],
              customer_zip: cols[22],
              customer_phone: cols[11],
              customer_plan: cols[12],
              card_number: cols[13],
              card_last_four: cols[14],
              card_expiration_date: cols[15],
              card_type: cols[16],
              amount: rand(20.0...10000.0).round(2),
              operation: ["DEP", "CASH"].sample
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
