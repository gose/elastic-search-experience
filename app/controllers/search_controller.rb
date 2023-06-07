class SearchController < ApplicationController

  before_action :init_repos

  include AllSearch
  include ATMSearch
  include EcommerceSearch
  include FlightsSearch
  include LogsSearch
  include LunchSearch
  include PeopleSearch
  include SchemaSearch
  include WikipediaBM25Search
  include WikipediaELSERSearch

  def index
    calculate_count
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
    # Default index is 'all'
    # Replace dashes with underscores for other indices
    # (we use dashes in the URL since they're easier to read)
    #
    if params[:index].present? && user_authorized?(params[:index])
      index = params[:index].gsub(/-/, "_")
    else
      index = "all"
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
      # Dynamically build the method name to be called, then call it.
      method = "#{index}_search".gsub(/-/, "-")
      @results, facets, @took =
        send(
          method.to_sym,
          @repos[index],
          "search",
          params[:q],
          params[:filters],
          params[:page],
          params[:sort]
        )
      @indices = ActiveSupport::OrderedHash.new
      @repos.each do |name, repo|
        @indices[name] = -1
        if Rails.cache.exist?("#{name}-#{params[:q]}")
          @indices[name] = Rails.cache.read("#{name}-#{params[:q]}")
        end
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

  def facets
    index = "all"
    index = params[:index].gsub(/-/, "_") if params[:index].present?

    # Dynamically build the method name to be called, then call it.
    method = "#{index}_search".gsub(/-/, "-")
    results, @facets, took =
      send(method.to_sym, @repos[index], "facet", params[:q], params[:filters], nil, nil)

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

  def counts
    @indices = ActiveSupport::OrderedHash.new
    @repos.each do |name, repo|
      @indices[name] = Rails
        .cache
        .fetch("#{name}-#{params[:q]}", expires_in: 1.minutes) do
          # Update the cache if it does not already have a value for this key.
          method = "#{name}_search"
          results, facets, took =
            send(method.to_sym, repo, "quick", params[:q], nil, nil, nil)
          results.total
        end
    end

    respond_to do |format|
      format.js {}
      format.html {}
    end
  end

  private

  def init_repos
    @repos = ActiveSupport::OrderedHash.new
    @repos['all'] = nil

    public_repos = [FlightsRepository, EcommerceRepository, LogsRepository, SchemaRepository]
    private_repos = [LunchRepository, PeopleRepository, ATMRepository,
                     WikipediaBM25Repository, WikipediaELSERRepository]

    index_names = []

    # All users get access to the public repositories.
    public_repos.each do |repo|
      begin
        idx = repo.new
        if idx.count
          @repos[idx.name] = idx
          index_names << idx.index_name
        end
      rescue StandardError => e
        logger.warn "Repo not found: #{repo}"
      end
    end

    # Only authenticated users get access to the private repositories.
    # Further ACL behavior would be handled with query filters.
    if current_user
      private_repos.each do |repo|
        begin
          idx = repo.new
          @repos[idx.name] = idx if idx.count
          index_names << idx.index_name
        rescue
          logger.warn "Repo not found: #{repo}"
        end
      end
    end

    @repos['all'] = AllRepository.new(index_name: index_names.join(','))
  end

  def user_authorized?(index)
    current_user || index == 'logs' || index == 'flights' || index == 'ecommerce' # || index == 'schema'
  end

  def calculate_count
    @count = 0
    @repos.each do |name, repo|
      @count += repo.count
    end
  end

end
