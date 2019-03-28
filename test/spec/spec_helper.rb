require 'rspec/core'
require 'hatchet'
require 'fileutils'
require 'hatchet'
require 'rspec/retry'
require 'date'
require 'json'
require 'sem_version'
require 'shellwords'

ENV['RACK_ENV'] = 'test'

def product_hash(hash)
	hash.values[0].product(*hash.values[1..-1]).map{ |e| Hash[hash.keys.zip e] }
end

RSpec.configure do |config|
	config.filter_run focused: true unless ENV['IS_RUNNING_ON_TRAVIS']
	config.run_all_when_everything_filtered = true
	config.alias_example_to :fit, focused: true
	config.full_backtrace      = true
	config.verbose_retry       = true # show retry status in spec process
	config.default_retry_count = 2 if ENV['IS_RUNNING_ON_TRAVIS'] # retry all tests that fail again
	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
	config.filter_run_excluding :requires_php_on_stack => lambda { |series| !php_on_stack?(series) }
end

def successful_body(app, options = {})
	retry_limit = options[:retry_limit] || 100 
	path = options[:path] ? "/#{options[:path]}" : ''
	Excon.get("http://#{app.name}.herokuapp.com#{path}", :idempotent => true, :expects => 200, :retry_limit => retry_limit).body
end

def expect_exit(expect: :to, operator: :eq, code: 0)
	raise ArgumentError, "Expected a block but none given" unless block_given?
	output = yield
	expect($?.exitstatus).method(expect).call(
		method(operator).call(code),
		"Expected exit code #{$?.exitstatus} #{expect} be #{operator} to #{code}; output:\n#{output}"
	)
	output # so that can be tested too
end

def expected_default_php(stack)
	case stack
		when "cedar-14", "heroku-16"
			"5.6"
		else
			"7.3"
	end
end

def php_on_stack?(series)
	case ENV["STACK"]
		when "cedar-14"
			available = ["5.5", "5.6", "7.0", "7.1", "7.2", "7.3"]
		when "heroku-16"
			available = ["5.6", "7.0", "7.1", "7.2", "7.3"]
		else
			available = ["7.1", "7.2", "7.3"]
	end
	available.include?(series)
end

def new_app_with_stack_and_platrepo(*args, **kwargs)
	kwargs[:stack] ||= ENV["STACK"]
	kwargs[:config] ||= {}
	kwargs[:config]["HEROKU_PHP_PLATFORM_REPOSITORIES"] ||= ENV["HEROKU_PHP_PLATFORM_REPOSITORIES"]
	kwargs[:config].compact!
	Hatchet::Runner.new(*args, **kwargs)
end

module Hatchet
  class App
    private def default_name
      "#{ENV['HATCHET_APP_PREFIX']}#{SecureRandom.hex(10)}"
    end
    def create_app
      3.times.retry do
        begin
          # heroku.post_app({ name: name, stack: stack }.delete_if {|k,v| v.nil? })
          hash = { name: name, stack: stack }
          hash.delete_if { |k,v| v.nil? }
          api_rate_limit.call.app.create(hash)
        rescue Excon::Error::HTTPStatus => e
          puts "Excon error from API in create_app, now reaping, then dumping request/response"
          @reaper.cycle
          p e.request
          p e.response
          raise e
        end
      end
    end
  end
  
  class TestRun
    def initialize(
      token:,
      buildpacks:,
      app:,
      pipeline:,
      api_rate_limit:,
      timeout:        10,
      pause:          5,
      commit_sha:     "sha",
      commit_branch:  "master",
      commit_message: "commit",
      organization:    nil
    )
      @pipeline        = pipeline || "#{ENV['HATCHET_APP_PREFIX']}#{SecureRandom.hex(10)}"
      @timeout         = timeout
      @pause           = pause
      @organization    = organization
      @token           = token
      @commit_sha      = commit_sha
      @commit_branch   = commit_branch
      @commit_message  = commit_message
      @buildpacks      = Array(buildpacks)
      @app             = app
      @mutex           = Mutex.new
      @status          = false
      @api_rate_limit  = api_rate_limit
    end
    attr_reader :app
  end
  
  class Reaper
    DEFAULT_REGEX = /^#{ENV['HATCHET_APP_PREFIX']}/
    def cycle
      get_apps
      if over_limit?
        if @hatchet_apps.count > 1
          destroy_oldest
          cycle
        else
          puts "Warning: Reached Heroku app limit of #{HEROKU_APP_LIMIT}."
        end
      else
        # do nothing
      end

    # If the app is already deleted an exception
    # will be raised, if the app cannot be found
    # assume it is already deleted and try again
    rescue Excon::Error::NotFound => e
      body = e.response.body
      if body =~ /Couldn\'t find that app./
        puts "#{@message}, but looks like it was already deleted"
        retry
      end
      raise e
    rescue Excon::Error::Forbidden => e
      puts "Got a 403, request and response dump follows"
      p e.request
      p e.response
      raise e
    end
  end
end
