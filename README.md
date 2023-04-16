# Elastic Search Experience

<img src="data/demo.gif" align="right" width="500" style="margin: 15px;"/>

The Elastic Search Experience (ESE) provides an intuitive search interface for your data.  Many people know how to use a search engine, and often turn to this simple interface to begin their quest for information.  The Elastic Search Experience satisfies this need, as a powerful tool to increase productivity by making large sets of data easily accessible.

The Elastic Search Experience is a customizable application that is configured to the needs of your users.  Templates are used to customize the search results  based on the data a user is searching.  Often times, data has to be presented in a particular way so that a user searching it can make sense of the results.  The Elastic Search Experience application is designed to be tailored towards these needs.

It's powered by Elasticsearch, which is a mature, scalable, open source, search engine.  Elasticsearch provides a flexible way to search over a wide variety of data.  The Elastic Search Experience application sits on top of it, and provides a friendly interface any user can understand with zero training.

This repository is for Search Teams looking to run a universal search interface on top of large sets of data.  It requires familiarity with Ruby on Rails to configure, customize, and run the application.  Integration points are provided to setup security, so that users can only see the search results for which they have permission.  If your team isn't familiar with Ruby on Rails, [Elastic.co](https://www.elastic.co) provides some great [alternatives](#alternatives) that contain a similar experience.

## Elastic

This application depends on an Elastic cluster.  You can use a local instance or one running inside Elastic Cloud.

Run a local Elastic cluster in Docker:

- [Run Elasticsearch locally on Docker](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)
- [Run Kibana locally on Docker](https://www.elastic.co/guide/en/kibana/8.7/docker.html)

## Setup

Clone the repo to local environment:

```bash
$ git clone github.com/gose/elastic-search-experience
```

Setup a new credential file:

```bash
$ rails credentials:edit
```

Add the following contents (replacing the example values):

```yaml
elastic_local:
  user: "elastic"
  password: "xxx"
  scheme: "https"
  host: "localhost"
  port: "9200"

elastic_cloud:
  user: "elastic"
  password: "xxx"
  scheme: "https"
  host: "xxx"
  port: "443"

elastic_apm:
  secret_token: "xxx"
  server_url: "xxx"

user:
  password: 'demo'
```

The application comes with a built-in `demo` user to simulate authenticated searches.  When deploying this application to production, using OAuth is recommended.

## Rails Query Flow

The data you have in Elasticsearch can be queried via the `search_controller.rb`.  It has many `concerns` that contain the logic for the different indices you'll be querying in Elasticsearch.  For example, the `lunch_search.rb` concern will contain most of the Elastic domain logic.

<img src="data/flow.png" width="800">

Results are rendered by the document type returned from Elasticsearch, using a partial view in `app/views/search`.  Check out the partial views for Lunch results in `_results-lunch.html.slim`.  It provides a good reference for creating your own custom results based on your data.

## Adding a Data Source

To add a new data source to your Elastic Search Page, follow these general steps.

<img src="data/steps.png" width="800">

Some logs in Elastic can contain many fields.  As you think about adding a new data source to your search page, sometimes it helps to write down the specific fields from a document that you want to search or render.  This can make it easier to onboard the data source without being overwhelmed by the number of fields some data sources contain.

## Alternatives

If you're looking to run something similar to this experience on your data, but you aren't familiar with Ruby on Rails, I encourage you to try [Elastic App Search](https://www.elastic.co/app-search/).  It comes with a nice React front-end called [Search UI](https://www.elastic.co/enterprise-search/search-ui) and an [Admin UI](https://www.elastic.co/app-search/).
