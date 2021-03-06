#
module Custom
  #
  class MultiCompany
    #
    attr_reader :company_class_name
    #
    def initialize(app, company_class, company_name_matcher)
      @app = app
      @company_class_name = company_class.to_s.split('_').collect!{ |w| w.capitalize }.join
      @company = Module.const_get(@company_class_name).find_by_company_name('DEFAULT') if db_configured
      @company_name_matcher = Module.const_get(
        company_name_matcher.to_s.split('_').collect!{ |w| w.capitalize }.join)
    end

    def call(env)
      request = Rack::Request.new(env)

      # - the matcher is an injected class with a to_domain method that makes it easy to replace
      # - with a different scheme of obtaining the company name from Request/Url.
      domain = @company_name_matcher.to_domain(request)

      # insert the company into ENV - for the controller helper_method 'current_company'
      retrieve_company_from_subdomain(domain.upcase)
      env['COMPANY_ID'] = @company.id unless @company.nil?
      @app.call(env)
    end

    private

    def db_configured
      ActiveRecord::Base.connection.table_exists? Module.const_get(@company_class_name).table_name
    end

    def retrieve_company_from_subdomain(domain)
      # - During test runs we load a company called 'DEFAULT' - it does not need to exist during initialisation
      @company = Module.const_get(@company_class_name).find_by_company_name('DEFAULT') if Rails.env == 'test'
      # - only ever load the company when the subdomain changes - also works when company is nil from an unsuccessful attempt..
      # - store the company_name to ensure we don't call the DB for each company request!
      @company.nil? ? @company_name = '' : @company_name = @company.company_name
      @company = Module.const_get(@company_class_name).find_by_company_name(domain) unless ( domain == @company_name )
      @company
    end
  end
end
