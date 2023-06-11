#!/usr/bin/env ruby

require 'json'
require 'zlib'

idx = 0
found = false

# Splitting this way due to size of main file
# and slicing it so we don't need to load it all into memory.
# ./split-file 1 &
# ./split-file 2 &
# ./split-file 3 &
# ...
# ./split-file 14 &
# Then gzip them all

data_file = "/home/ubuntu/data/wikipedia/enwiki-20230410-cirrussearch-content.json.gz"
out_file = "/home/ubuntu/data/wikipedia/enwiki-20230410-cirrussearch-content-#{ARGV[0]}.json"

Zlib::GzipReader.open(data_file) do |file|
  file
    .lazy
    .each_slice(100) do |lines|
      lines.each do |line|
        if idx >= "#{ARGV[0].to_i - 1}_000_000".to_i && idx < "#{ARGV[0]}_000_000".to_i
          File.write(out_file, line, mode: 'a')
          found = true
        else
          exit if found
        end
        idx += 1
      end
    end
end
