module ApplicationHelper

  def middle_truncate(str, total: 80, lead: 40, trail: 40)
    str.truncate(total, omission: "#{str.first(lead)}...#{str.last(trail)}")
  end

  def highlight(string)
    return if string.blank?
    return string if params[:q].blank?

    if params[:q] =~ /:/
      q = params[:q].split(/: /)[1]
      if q
        raw string.gsub(/(#{q})/i, '<em>\1</em>')
      else
        raw string
      end
    elsif string =~ /#{params[:q]}/i
      raw string.gsub(/(#{params[:q]})/i, '<em>\1</em>')
    else
      string
    end
  end

  def facet_selected(name)
    if params[:filters].present?
      filter_pairs = params[:filters].split(/--/)
      for filter_pair in filter_pairs
        key, val = filter_pair.split(/:/)
        if key == name
          return val
        end
      end
    end
    return nil
  end

  def remove_filter(name, value)
    filters = {}
    if params[:filters]
      # filters=Category:foo--Price:bar--Author:joe
      current_filters = params[:filters].dup
      filters_string = current_filters.split(/--/)
      filters_string.each do |filter_pairs|
        k, v = filter_pairs.split(/:/)
        filters[k] = v
      end
      # Maybe extend for 'or' filters in the future.
      filters.delete(name)
      if filters.count > 0
        return filters.map{|k,v| "#{k}:#{v}"}.join('--')
      else
        return nil
      end
    end
  end

  def add_filter(name, value)
    filters = {}
    if params[:filters].present?
      # filters=Category:foo--Price:bar--Author:joe
      current_filters = params[:filters].dup
      filters_string = current_filters.split(/--/)
      filters_string.each do |filter_pairs|
        k, v = filter_pairs.split(/:/)
        filters[k] = v
      end
      filters[name] = value
      return filters.map{|k,v| "#{k}:#{v}"}.join('--')
    else
      return "#{name}:#{value}"
    end
  end

  def s3_asset_path(asset)
    "https://gose.s3.amazonaws.com/elastic/" + asset
  end

end
