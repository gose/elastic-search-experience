module ApplicationHelper

  def markdown(text)
    options = {
      filter_html: false,
      hard_wrap: true,
      link_attributes: {
        rel: 'nofollow',
        target: '_blank'
      },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: true
    }

    renderer = Redcarpet::Render::HTML.new(options)
    markdown = Redcarpet::Markdown.new(renderer, extensions)

    markdown.render(text).html_safe
  end

  def middle_truncate(str, total: 80, lead: 40, trail: 40)
    str.truncate(total, omission: "#{str.first(lead)}...#{str.last(trail)}")
  end

  def highlight(string)
    return "" unless string.present?
    return string if params[:q].blank?

    if params[:q] =~ /:/
      q = params[:q].split(/: /)[1]
      if q
        raw string.gsub(/(#{q})/i, '<em>\1</em>')
      else
        raw string
      end
    elsif params[:q].split.count > 1
      params[:q].split do |token|
        string.gsub!(/(#{token})/i, '<em>\1</em>')
      end
      raw string
    else
      raw string.to_s.gsub(/(#{params[:q]})/i, '<em>\1</em>')
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
