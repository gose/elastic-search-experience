Rails.application.routes.draw do

  root 'search#index'

  get '/search/(:index)' => 'search#show', :as => 'search'
  get '/facets/(:index)' => 'search#facets', :as => 'facets'
  get '/counts/(:index)' => 'search#counts', :as => 'counts'
  post '/preferences' => 'pages#preferences', :as => 'preferences'

  get '/healthcheck' => 'application#healthcheck'

  get 'login' => 'pages#login', :as => 'login'
  get 'logout' => 'pages#logout', :as => 'logout'
  post 'auth' => 'pages#auth', :as => 'auth'

  get '/privacy' => 'pages#privacy', :as => 'privacy'
  post '/feedback' => 'pages#feedback', :as => 'feedback'

end
