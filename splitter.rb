#
# ELSER will split by 512 with 256 overlap.
#

module TextSplitters
  class RecursiveCharacterTextSplitter
    def initialize(chunk_size:, chunk_overlap:)
      @chunk_size = chunk_size
      @chunk_overlap = chunk_overlap
      @separators = ["\n\n", "\n", " ", ""]
    end

    def split(text)
      output = []
      good_splits = []

      separator = @separators.last
      @separators.each do |s|
        if text.include?(s)
          separator = s
          break
        end
      end
      splits = text.split(separator)

      splits.each do |s|
        if s.length < @chunk_size
          good_splits << s
        else
          if good_splits.any?
            merged_text = merge_splits(good_splits, separator)
            output.concat(merged_text)
            good_splits = []
          end

          other_info = split(s)
          output.concat(other_info)
        end
      end

      if good_splits.any?
        merged_text = merge_splits(good_splits, separator)
        output.concat(merged_text)
      end

      output
    end

    private

    def merge_splits(splits, separator)
      output = []
      current_doc = []
      total = 0

      splits.each do |split|
        if total + split.length >= @chunk_size && current_doc.any?
          doc = current_doc.join(separator).strip
          output << doc if doc && !doc.empty?

          while total > @chunk_overlap || (total > 0 && (total + split.length > @chunk_size))
            total -= current_doc.first.length
            current_doc.shift
          end
        end
        current_doc << split
        total += split.length
      end
      doc = current_doc.join(separator).strip
      output << doc if doc && !doc.empty?

      output
    end
  end
end
