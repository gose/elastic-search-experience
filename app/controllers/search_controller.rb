class SearchController < ApplicationController
  include AllSearch
  include PublicSearch

  # Public Repos
  include EcommerceSearch
  include FlightsSearch
  include LogsSearch

  # Private Repos
  include LunchSearch
  include PeopleSearch

  PUBLIC_REPOS = %w[logs ecommerce flights]
  PRIVATE_REPOS = %w[lunch people]

  def index
    calculate_count
  end

  def counts
    @indices = ActiveSupport::OrderedHash.new
    repos = PUBLIC_REPOS
    repos += PRIVATE_REPOS if current_user
    repos.each do |index|
      @indices[index] = Rails
        .cache
        .fetch("#{index}-#{params[:q]}", expires_in: 1.minutes) do
          # Update the cache if it does not already have a value for this key.
          method = "#{index}_search"
          results, facets, took =
            send(method.to_sym, "quick", params[:q], nil, nil, nil)
          results.total
        end
    end

    respond_to do |format|
      format.js {}
      format.html {}
    end
  end

  def facets
    index = "all"
    index = params[:index].gsub(/-/, "_") if params[:index].present?

    if current_user
      # Dynamically build the method name to be called, then call it.
      method = "#{index}_search".gsub(/-/, "-")
      results, @facets, took =
        send(method.to_sym, "facet", params[:q], params[:filters], nil, nil)
    else
      if index == "ecommerce"
        results, @facets, took =
          ecommerce_search("facet", params[:q], params[:filters], nil, nil)
      elsif index == "flights"
        results, @facets, took =
          flights_search("facet", params[:q], params[:filters], nil, nil)
      elsif index == "logs"
        results, @facets, took =
          logs_search("facet", params[:q], params[:filters], nil, nil)
      else
        results, @facets, took =
          public_search("facet", params[:q], params[:filters], nil, nil)
      end
    end

    if Rails.env.production?
      LogSearchRequestJob.perform_later(
        {
          timestamp: "#{Time.now.utc.iso8601}",
          session_id: "#{session.id}",
          user: current_user,
          action: "facet",
          index: "#{params[:index]}",
          query: "#{params[:q]}",
          filters: "#{params[:filters]}",
          sort: "#{params[:sort]}",
          page: "#{params[:page]}",
          took: "#{took}",
          count: "#{results.total}"
        }
      )
    end

    respond_to do |format|
      format.js {}
      format.html {}
    end
  end

  def show
    #
    # Keyword Redirects
    #
    if params[:q] == "logout"
      render js: "window.location = '/logout'"
    elsif params[:q] == "login"
      render js: "window.location = '/login'"
    end

    #
    # Default index is 'public'
    # Replace dashes with underscores for other indices
    # (we use dashes in the URL since they're easier to read)
    #
    if params[:index].present? && user_authorized?(params[:index])
      index = params[:index].gsub(/-/, "_")
    else
      index = "public"
    end

    #
    # Parse the query
    #
    if params[:q] == "ds" || params[:q] == "data sources" || params[:q] == "dl"
      @ds = []
      for dir in %w[
        apm-server
        atm
        divvy
        elasticsearch-filebeat-module
        elasticsearch-metricbeat-module
        flight-tracker
        flights
        haproxy-filebeat-module
        haproxy-metricbeat-module
        lunch
        nginx
        people
        system-filebeat-module
        system-metricbeat-module
        truenas-syslog
        ubiquiti-syslog
        utilization
      ]
        indexed = false
        indexed = true if dir == "utilization" || dir == "nginx" ||
          dir == "atm" || dir == "flights" || dir == "apm-server"
        last_seen = rand(2..18)
        @ds << {
          name: dir,
          last_seen: "#{last_seen} minutes ago",
          indexed: indexed
        }
      end
      @indices = ActiveSupport::OrderedHash.new
      %w[docs].each { |index| @indices[index] = -1 }
    elsif params[:index].present? &&
          params[:q] == "ea06a14d-625a-4507-af9b-b1f959db2185"
      @doc = File.read("public/sample.json")
    elsif index.present? && request.xhr?
      #
      # A normal search request, broken out into authenticated users and non-authenticated.
      #
      if current_user
        # Dynamically build the method name to be called, then call it.
        method = "#{index}_search".gsub(/-/, "-")
        @results, facets, @took =
          send(
            method.to_sym,
            "search",
            params[:q],
            params[:filters],
            params[:page],
            params[:sort]
          )
        @indices = ActiveSupport::OrderedHash.new
        repos = PUBLIC_REPOS
        repos += PRIVATE_REPOS if current_user
        repos.each do |index|
          @indices[index] = -1
          if Rails.cache.exist?("#{index}-#{params[:q]}")
            @indices[index] = Rails.cache.read("#{index}-#{params[:q]}")
          end
        end
      else
        if index == "ecommerce"
          @results, facets, @took =
            ecommerce_search(
              "search",
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        elsif index == "flights"
          @results, facets, @took =
            flights_search(
              "search",
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        elsif index == "logs"
          @results, facets, @took =
            logs_search(
              "search",
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        else
          @results, facets, @took =
            public_search(
              "search",
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        end
        @indices = ActiveSupport::OrderedHash.new
        repos = PUBLIC_REPOS
        repos.each { |index| @indices[index] = -1 }
      end

      if Rails.env.production?
        LogSearchRequestJob.perform_later(
          {
            timestamp: "#{Time.now.utc.iso8601}",
            session_id: "#{session.id}",
            user: current_user,
            action: "search",
            index: "#{params[:index]}",
            query: "#{params[:q]}",
            filters: "#{params[:filters]}",
            sort: "#{params[:sort]}",
            page: "#{params[:page]}",
            took: "#{@took}",
            count: "#{@results.total}"
          }
        )
      end
    end

    calculate_count

    respond_to do |format|
      format.js {}
      format.html {}
    end
  end

  private

  def user_authorized?(index)
    if current_user
      return PRIVATE_REPOS.include?(index) || PUBLIC_REPOS.include?(index)
    else
      return PUBLIC_REPOS.include?(index)
    end
  end

  def calculate_count
    if current_user
      @count = all_count
    else
      @count = public_count
    end
  end

  def public_count
    flights = FlightsRepository.new
    ecommerce = EcommerceRepository.new
    logs = LogsRepository.new
    flights.count + ecommerce.count + logs.count
  end

  def all_count
    lunch = LunchRepository.new
    people = PeopleRepository.new
    lunch.count + people.count + public_count
  end
end
