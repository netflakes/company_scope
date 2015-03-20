# CompanyScope

This is a simple solution to scoping a rails project for multi-tenancy. It is based on the default_scope
in Active Record. Currently it uses a fixed model called company for the account/scoping.

Since the whole process needs a thread_safe way to store the current company identifier (such as a subdomain) as a class attribute, the gem uses the RequestStore gem to store this value.

Thread.current is the usual way to handle this but this is not entirely compatible with all ruby application servers - especially the Java based ones. RequestStore is the solution that works in all such application servers.

## Travis CI

[![Build Status](https://travis-ci.org/netflakes/company_scope.svg?branch=master)](https://travis-ci.org/netflakes/company_scope)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'company_scope'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install company_scope

## Usage

Getting started
===============
There are three main steps in adding multi-tenancy/company to your app with company_scope:

1. Decide on a process of determining the company/account. Such as using the sub-domain.
2. Setting the current company and controller based setup.
3. Scoping your models.


### Decide on a process of determining the company/account ###

In the current version a helper_method called "current_company" is added to the Controller,
where you add the method "company_setup". You have therefore two choices. Either you use the
company_scope gem process included Rack Middleware or your own process to set the instance
of "Company" into "request.env".

The included Rack Middleware can be inserted into the Rails Application stack in the config
section of 'application.rb'.

```ruby
module YourRailsApp
  class Application < Rails::Application
    ...
    # - add some Rack middleware to detect the company_name from the subdomain
    config.middleware.insert_after Rack::Sendfile, Rack::MultiCompany, :company
    ...
  end
end
```

The parameter in the example above needs to be a symbol of the model of your application
that will act as the account i.e. company, tenant etc.

The domain 'lvh.me' points to 127.0.0.1 and is therefore an ideal candidate for using with local development and subdomains since they will also all point to your localhost.

[See here for info](http://stackoverflow.com/questions/12983072/rails-3-subdomain-testing-using-lvh-me)

NB: The middleware currently uses a regex to ensure the domain name can only obtain the following:

* A-Z
* a-z
* 0-9

The middleware then uses the column called "class_name"_name i.e. "company_name"

No spaces or special characters are permitted and the name is also upcased - which needs to be handled
by the model you use for scoping! This just keeps the name clean and simple.
We would strongly recommend you to have a proper index on the company

The method below is included in the Controller stack (see notes further down), and retrieves
the company object the request object. The Rack Middleware "Rack::MultiCompany" injects this
object into each request!

```ruby
def current_company
  request.env["COMPANY_ID"]
end
```

An example of how the gem does this using "Rack Middleware" - is in the excerpt below:

```ruby
def call(env)
  request = Rack::Request.new(env)
  domain = request.host.split('.').first.upcase
  env["COMPANY_ID"] = your_custom_method_to_retrieve_company_from_subdomain(domain)
  response = @app.call(env)
  response
end
```

Alternatively you can use your own process for determining the "current_company" and override this
method in your application controller, providing you declare this after the "company_setup" method,
which is detailed in the next step.


### Setting the current company and controller based setup ###

```ruby
class ApplicationController < ActionController::Base

  company_setup

  set_scoping_class :company

  acts_as_company_filter

end
```

The above three methods need to be added to the Rails Controllers. For small systems they
will typically be added to the ApplicationController. However they can be split into
child-controllers dependent on the layout of the application.

All Controllers that inherit from the Controller that implements the "acts_as_company_filter"
will have an around filter applied that set the Company class attribute required for the scoping
process.

The "company_setup" method adds some helper methods that are available to all child controllers.

* company_setup
* set_scoping_class :company
* acts_as_company_filter

The "set_scoping_class :company" method tells CompanyScope that we have a model called Company, and
it will be the model that all others will be scoped with.
The method parameter defaults to :company but can be another model of your choosing such as Account.
Each model that is scoped by the Company needs to have the company_id column.

NB: The "CompanyScope" gem does not handle the process of adding migrations or changes to the DB.


### Scoping your models ###

* The "acts_as_guardian" method injects the behaviour required for the scoping model.

```ruby
class Company < ActiveRecord::Base

  acts_as_guardian

  ...

end
```

The gem also injects


* Each class to be scoped needs to have the "acts_as_company :account" method. The parameter ":account"
defaults to :company if left blank. This can be any class/name of your choosing - the parameter needs
to be a underscored version of the Class name as a symbol.

```ruby
class User < ActiveRecord::Base

  acts_as_company :account  # Defaults to :company if left blank!

  # NB - don't add 'belongs_to :company' or validation
  # of the 'company_id' since the gem does this for you.

  ...
end
```


## Development


## Contributing

1. Fork it ( https://github.com/[my-github-username]/company_scope/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
