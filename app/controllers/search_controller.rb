class SearchController < ApplicationController
  include AllSearch

  # Public
  include EcommerceOrders
  include FlightData
  include WebLogs

  # Private
  include LunchSearch
  include PeopleSearch

  def index
    @count = count
  end

  def facets
    index = 'all'
    index = params[:index].gsub(/-/, '_') if params[:index].present?

    if current_user
      # Dynamically build the method name to be called, then call it.
      method = "#{index}_search".gsub(/-/, '-')
      results, @facets, took =
        send(method.to_sym, 'facet', params[:q], params[:filters], nil, nil)
    else
      if index == 'ecommerce_orders'
        results, @facets, took =
          ecommerce_orders_search(
            'facet',
            params[:q],
            params[:filters],
            nil,
            nil
          )
      elsif index == 'flight_data'
        results, @facets, took =
          flight_data_search('facet', params[:q], params[:filters], nil, nil)
      elsif index == 'web_logs'
        results, @facets, took =
          web_logs_search('facet', params[:q], params[:filters], nil, nil)
      elsif index == 'people'
        results, @facets, took =
          people_search('facet', params[:q], params[:filters], nil, nil)
      elsif index == 'lunch'
        results, @facets, took =
          lunch_search('facet', params[:q], params[:filters], nil, nil)
      else
        results, @facets, took =
          all_search('facet', params[:q], params[:filters], nil, nil)
      end
    end

    if Rails.env.production?
      LogSearchRequestJob.perform_later(
        {
          timestamp: "#{Time.now.utc.iso8601}",
          session_id: "#{session.id}",
          user: current_user,
          action: 'facet',
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
    # Keywords
    if params[:q] == 'logout'
      render js: "window.location = '/logout'"
    elsif params[:q] == 'login'
      render js: "window.location = '/login'"
    end

    index = 'all'
    index = params[:index].gsub(/-/, '_') if params[:index].present?

    if index.present? && request.xhr?
      if current_user
        # Dynamically build the method name to be called, then call it.
        method = "#{index}_search".gsub(/-/, '-')
        @results, facets, @took =
          send(
            method.to_sym,
            'search',
            params[:q],
            params[:filters],
            params[:page],
            params[:sort]
          )
        @indices = ActiveSupport::OrderedHash.new
        %w[
          all
          web_logs
          flight_data
          ecommerce_orders
          search_history
          feedback
          lunch
          people
        ].each do |index|
          @indices[index] = -1 # results.total
        end
      else
        if index == 'ecommerce_orders'
          @results, facets, @took =
            ecommerce_orders_search(
              'search',
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        elsif index == 'flight_data'
          @results, facets, @took =
            flight_data_search(
              'search',
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        elsif index == 'web_logs'
          @results, facets, @took =
            web_logs_search(
              'search',
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        elsif index == 'lunch'
          @results, facets, @took =
            lunch_search(
              'search',
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        elsif index == 'people'
          @results, facets, @took =
            people_search(
              'search',
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        else
          @results, facets, @took =
            all_search(
              'search',
              params[:q],
              params[:filters],
              params[:page],
              params[:sort]
            )
        end
        @indices = ActiveSupport::OrderedHash.new
        %w[
          all
          web_logs
          flight_data
          ecommerce_orders
          lunch
          people
        ].each { |index| @indices[index] = -1 }
      end

      if Rails.env.production?
        LogSearchRequestJob.perform_later(
          {
            timestamp: "#{Time.now.utc.iso8601}",
            session_id: "#{session.id}",
            user: current_user,
            action: 'search',
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

    @count = count

    respond_to do |format|
      format.js {}
      format.html {}
    end
  end

  private

  def count
    if current_user
      feedback = FeedbackRepository.new
      search_history = SearchHistoryRepository.new
      return public_count + feedback.count + search_history.count
    else
      return public_count
    end
  end

  def public_count
       # Public
      flights = FlightDataRepository.new
      orders = EcommerceOrdersRepository.new
      logs = WebLogsRepository.new
      return flights.count + orders.count + logs.count
  end
end
