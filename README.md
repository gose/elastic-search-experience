# Elastic Search Experience

<img src="data/screenshot.png" align="right" height="280" style="margin-top: -25px;" />

The Elastic Search Experience (ESE) provides an intuitive search interface for your data.  Its goal is to bring transparency to your data through the power of search.  Many people know how to use a search engine, and often turn to this simple interface to begin their quest for information.  The Elastic Search Experience satisfies this need, as a powerful tool to increase productivity by making large sets of data easily accessible.

The Elastic Search Experience is a customizable application that is configured to the needs of your users.  Templates are used to customize the search results  based on the data a user is searching through.  Often times, data has to be presented in a particular way so that a user searching it can make sense of the results.  The Elastic Search Experience application is designed to be tailored towards these needs.

It's powered by Elasticsearch, which is a mature, scalable, open source, search engine.  Elasticsearch provides a flexible way to search over a wide variety of data.  The Elastic Search Experience application sits on top of it, and provides a friendly interface any user can understand with zero training.

This repository is for Search Teams looking to run a universal search interface on top of large sets of data.  It requires familiarity with Ruby on Rails to configure, customize, and run the application.  Integration points are provided to setup security, so that users can only see the search results for which they have permission.

## Getting Started

If you'd like to run this application in your environment, you'll need to be familiar with running a Ruby on Rails applciation, along with general system knowledge.  If you or your team isn't familiar with Ruby on Rails, [Elastic.co](https://www.elastic.co) provides some great [alternatives](#alternatives) that contain a similar experience.

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
elastic_cloud:
  cloud_id: "My_Cluster:Cloud_ID"
  user: "elastic"
  password: "My_Password"
  scheme: "https"
  host: "my-hostname.us-central1.gcp.cloud.es.io"
  port: "9243"

elastic_apm:
  secret_token: "my-apm-token"

users:
  a-user: "my-password"
  b-user: "my-password"
```

The application comes with two built-in users `a-user` and `b-user` which you should tailor to your needs.  When deploying this application to production, using OAuth is recommended if you need to support many users.

The data you have in Elasticsearch can be queried via the `search_controller.rb`.  It has many `concerns` that contain the logic for the different indices you'll be querying in Elasticsearch.  For example, the `wikipedia_search.rb` concern or the `elastic_docs_search.rb` concern .  You can use those as a reference when you're ready to add your own data types from your Elasticsearch cluster.

Results are rendered by the document type returned from Elasticsearch, using a partial view in `app/views/search`.  Check out the partial views for Wikipedia results in `_resutls-wikipedia.html.slim` and for Elastic Docs in `_results-docs.html.slim`.  They provide a good reference for creating your own custom result reviews based on your data.

## Adding a Data Source

To add a new data source to your Elastic Search Page, follow these general steps.



![Screenshot](data/steps.png)

Some logs in Elastic can contain many fields.  As you think about adding a new data source to your search page, sometimes it helps to write down the specific fields from a document that you want to search or render.  This can make it easier to onboard the data source without being overwhelmed by the number of fields some data sources contain.

## Alternatives

If you're looking to run something similar to this experience on your data, but you aren't familiar with Ruby on Rails, I encourage you to try [Elastic App Search](https://www.elastic.co/app-search/).  It comes with a nice React front-end called [Search UI](https://www.elastic.co/enterprise-search/search-ui) and an [Admin UI](https://www.elastic.co/app-search/).
