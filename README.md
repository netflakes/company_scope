# CompanyScope

This is a simple solution to scoping a rails project for multi-tenancy. It is based on the default_scope
in Active Record. Currently it uses a fixed model called company for the account/scoping.

Since the whole process needs a thread_safe way to store the current company identifier (such as a subdomain) as a class attribute, the gem uses the RequestStore gem to store this value.

Thread.current is the usual way to handle this but this is not entirely compatible with all ruby application servers - especially the Java based ones. RequestStore is the solution that works in all such application servers.

## Travis CI

[![Build Status](https://travis-ci.org/netflakes/company_scope.svg?branch=master)](https://travis-ci.org/netflakes/company_scope)

## Coveralls

[![Coverage Status](https://coveralls.io/repos/netflakes/company_scope/badge.svg)](https://coveralls.io/r/netflakes/company_scope)

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

1. Run the install generator
2. Determine the company/account. Such as using the sub-domain.
3. Setting the current company and controller based setup.
4. Scoping your models.

### Run the install generator

The gem has an install generator that adds a configuration setting to config/application.rb
and also creates two models with associated migrations. The models are company and user.
The company has the acts_as_guardian company_scope module inserted, and the user has
the acts_as_company company_scope module inserted. It finally also adds the filtering configuration
into the Application Controller. (See further below for an explanation)

```
rails generate company_scope:install
```

If you are planning to use different models or to modify existing models you can run the
install generator without the migrations and model creation as follows

```
rails generate company_scope:install --no_migrations
```

### Enabling the company_scope gem!

The install generator also added a configuration setting into config/application.rb that needs
to be enabled once the configuration is completed.

```
  class Application < Rails::Application
    config.company_scope[:configured] = false

```

This is deliberately set to false at the outset. Set this to true AFTER all the configuration of
the gem is completed, i.e. the company model exists and you have run the migration.

### Process of determining the company/account

In the current version a helper_method called "current_company" is added to the Controller,
where you add the method "company_setup". The gem includes Rack Middleware that injects the
"Company ID" into "request.env".

The included Rack Middleware is inserted into the Rails Application stack automatically.
The defaults are to use the an ActiveRecord model called company for the scoping model.
The process of determining the company name from the request is done by extracting the
subdomain i.e. the first section in dotted url notation.

The example shows the default settings. If you use the default you do NOT need to set this
in the application.rb file. If however you want to use a different scoping model and a
different matching process you need to change these.

```ruby
module YourRailsApp
  class Application < Rails::Application
    ...
    # - These are the DEFAULTS and are set automatically..
    # - you only need to set these if you change them!
    config.company_scope.company_model = :company
    config.company_scope.company_name_matcher = :subdomain_matcher
    ...
  end
end
```

The symbol parameter passed to the .company_model configuration in the example above needs
to be a symbol of the model of your application that will act as the account i.e. company,
tenant etc.

The symbol parameter passed to the .company_name_matcher configuration is the underscored
version of the class that is used to handle the matching. All it needs to implement is a
method called to_domain(request) that takes the request as the parameter. It needs to return
the company name as a string as:

```ruby
class MyCustomDomainMatcher
  def self.to_domain(request)
    .... my custom logic to extrapoulate the company name
    company_name # the return value must be the company_name as a string.
  end
```
And then include this in the application.rb

```ruby
module YourRailsApp
  class Application < Rails::Application
    ...
    config.company_scope.company_name_matcher = :my_custom_domain_matcher
    ...
  end
end
```

The domain 'lvh.me' points to 127.0.0.1 and is therefore an ideal candidate for using with local development and subdomains since they will also all point to your localhost.

[See here for info](http://stackoverflow.com/questions/12983072/rails-3-subdomain-testing-using-lvh-me)

NB: The middleware currently uses a regex to ensure the domain name can only obtain the following:

* A-Z, a-z, 0-9

The middleware then uses the column called "company_name" to retrieve the company by the subdomain.

The name is also upcased - which needs to be handled by the model you use for scoping! This just keeps the name clean and simple. We would strongly recommend you to have a proper index on the company_name field.

NB: If you are using a different model and don't like the idea of using the company_name field you can simply
use the ruby alias method.

```ruby
alias_method :company_name, :your_account_name_method
```

The method below is included in the Controller stack (see notes further down), and retrieves
the company object the request object. The Rack Middleware "Rack::MultiCompany" injects this
object into each request! It raises an CompanyAccessViolationError if the id is nil. There is
an extra filter added to handle these errors and redirects to a custom route called: wrong_company_path

```ruby
def current_company_id
  request.env["COMPANY_ID"]
end
```

An example of adding the wrong_company_path route in a rails app:

```ruby

 get 'wrong_company' => 'invalid_company#index', as: :wrong_company

```

### Setting the current company and controller based setup

```ruby
class ApplicationController < ActionController::Base

  company_setup

  set_scoping_class :company

  acts_as_company_filter

end
```

The above three methods have been added to the Rails Application Controller, by the install
generator. For small systems they will typically remain there unless you have pages that do
not require to be scoped by the company in which case they should be added to a child.

All Controllers that inherit from the Controller that implements the acts_as_company_filter
will have an around filter applied that set the Company class attribute required for the scoping
process.

The 'company_setup' method adds some helper methods that are available to all child controllers.

* company_setup
* set_scoping_class :company
* acts_as_company_filter

The 'set_scoping_class :company' method tells CompanyScope that we have a model called Company, and
it will be the model that all others will be scoped with.
The method parameter defaults to :company but can be another model of your choosing such as Account.
Each model that is scoped by the Company needs to have the company_id column.


### Scoping your models

* The 'acts_as_guardian' method injects the behaviour required for the scoping model. The model
needs to have a string column that is called by the 'model'_name i.e. 'company_name'. The gem
adds a uniqueness validator. NB to ensure this will not cause race conditions at the DB level
you really need to add an index for this column.

```ruby
class Company < ActiveRecord::Base

  acts_as_guardian

  # NB - the gem adds a uniqueness validator for the company_name field

end
```

The gem also injects


* Each class to be scoped needs to have the 'acts_as_company :account' method. The parameter ':account'
defaults to :company if left blank. This can be any class/name of your choosing. The parameter needs
to be a underscored version of the Class name as a symbol.

```ruby
class User < ActiveRecord::Base

  acts_as_company :account  # Defaults to :company if left blank!

  # NB - don't add 'belongs_to :company' or validation
  # of the 'company_id' since the gem does this for you.

  ...
end
```

#### The Gem is currently being used in Rails 4 and Rails-API apps and is tested against Postgres

#### It should work with other databases such as MySQL without any issues

### Contributing

1. Fork it ( https://github.com/[my-github-username]/company_scope/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
