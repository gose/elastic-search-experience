#!/usr/bin/env ruby

require 'json'

idx = -1

data_file = "/Users/gose/data/wikipedia/enwiki-20230410-cirrussearch-content.json.gz"

Zlib::GzipReader.open(data_file) do |file|
  # File.open(data_file) do |file|
    file
      .lazy
      .each_slice(100) do |lines|
        # print '.'
        batch_for_bulk = []
        id = nil
        lines.each do |line|
          idx += 1
          next if args[:million] == 0 && idx > 1_000_000
          next if args[:million] == 1 && (idx <= 1_000_000 || idx > 2_000_000)
          next if args[:million] == 2 && (idx <= 2_000_000 || idx > 3_000_000)
          next if args[:million] == 3 && (idx <= 3_000_000 || idx > 4_000_000)
          next if args[:million] == 4 && (idx <= 4_000_000 || idx > 5_000_000)
          next if args[:million] == 5 && (idx <= 5_000_000 || idx > 6_000_000)
          next if args[:million] == 6 && (idx <= 6_000_000 || idx > 7_000_000)
          next if args[:million] == 7 && (idx <= 7_000_000 || idx > 8_000_000)
          next if args[:million] == 8 && (idx <= 8_000_000 || idx > 9_000_000)
          next if args[:million] == 9 && (idx <= 9_000_000 || idx > 10_000_000)
          next if args[:million] == 10 && (idx <= 10_000_000 || idx > 11_000_000)
          next if args[:million] == 11 && (idx <= 11_000_000 || idx > 12_000_000)
          next if args[:million] == 12 && (idx <= 12_000_000 || idx > 13_000_000)

=begin
File.foreach("/Users/gose/data/wikipedia/enwiki-20230410-cirrussearch-content.json") do |line|
# File.foreach("head-1000.json") do |line|
  next if line =~ /^{"index":{"_type":"_doc"/
  i += 1
  parsed = JSON.parse(line)
  if parsed["title"] =~ /Chevy Chase/
    puts '---'
    puts i
    puts parsed["title"]
    puts parsed["opening_text"]
    exit
  end
end
=end
