# encoding: utf-8
require 'sidekiq/version'
require 'sidekiq/logging'
require 'sidekiq/client'
require 'sidekiq/worker'
require 'sidekiq/redis_connection'
require 'sidekiq/util'
require 'sidekiq/api'

require 'json'

module Sidekiq
  NAME = "Sidekiq"
  LICENSE = 'See LICENSE and the LGPL-3.0 for licensing details.'

  DEFAULTS = {
    :queues => [],
    :concurrency => 25,
    :require => '.',
    :environment => nil,
    :timeout => 8,
    :profile => false,
    :scheduled_queue_name => "scheduled",
    :retry_queue_name => "retry",
    :queue_prefix => "sidekiq.queue"
  }

  def self.❨╯°□°❩╯︵┻━┻
    puts "Calm down, bro"
  end

  def self.options
    @options ||= DEFAULTS.dup
  end

  def self.options=(opts)
    @options = opts
  end

  ##
  # Configuration for Sidekiq server, use like:
  #
  #   Sidekiq.configure_server do |config|
  #     config.redis = { :namespace => 'myapp', :size => 25, :url => 'redis://myhost:8877/0' }
  #     config.server_middleware do |chain|
  #       chain.add MyServerHook
  #     end
  #   end
  def self.configure_server
    yield self if server?
  end

  ##
  # Configuration for Sidekiq client, use like:
  #
  #   Sidekiq.configure_client do |config|
  #     config.redis = { :namespace => 'myapp', :size => 1, :url => 'redis://myhost:8877/0' }
  #   end
  def self.configure_client
    yield self unless server?
  end

  def self.server?
    defined?(Sidekiq::CLI)
  end

  def self.redis(&block)
    raise ArgumentError, "requires a block" if !block
    @redis ||= Sidekiq::RedisConnection.create(@redis_hash || {})
    @redis.with(&block)
  end

  def self.redis=(hash)
    return @redis = hash if hash.is_a?(ConnectionPool)

    if hash.is_a?(Hash)
      @redis_hash = hash
    else
      raise ArgumentError, "redis= requires a Hash or ConnectionPool"
    end
  end

  def self.bunny(&block)
    raise ArgumentError, "requires a block" if !block
    @bunny ||= Bunny.new(@bunny_hash || {})
    new_connection = false
    if !@bunny.connected?
      new_connection = true
      @bunny.start
      #Sidekiq::Logging.logger.warn("NOT CONNECTED!!")
#      @channel = @bunny.create_channel
    end

    if !@channel || @channel.closed? || new_connection
      @channel = @bunny.create_channel
    end

    yield @channel
  end

  def self.bunny=(hash)
    return @bunny = hash if hash.is_a?(Bunny)
    if hash.is_a?(Hash)
      @bunny_hash = hash
    else
      raise ArgumentError, "bunny= requires a Hash or a Bunny connection"
    end
  end

  def self.queue_prefix
    self.options[:queue_prefix]
  end

  def self.canonical_queue_name(queue_name)
    "#{Sidekiq.queue_prefix}.#{queue_name}"
  end

  def self.client_middleware
    @client_chain ||= Middleware::Chain.new
    yield @client_chain if block_given?
    @client_chain
  end

  def self.server_middleware
    @server_chain ||= Processor.default_middleware
    yield @server_chain if block_given?
    @server_chain
  end

  def self.default_worker_options=(hash)
    @default_worker_options = default_worker_options.merge(hash)
  end

  def self.default_worker_options
    @default_worker_options || { 'retry' => true, 'queue' => 'default' }
  end

  def self.load_json(string)
    JSON.parse(string)
  end

  def self.dump_json(object)
    JSON.generate(object)
  end

  def self.logger
    Sidekiq::Logging.logger
  end

  def self.logger=(log)
    Sidekiq::Logging.logger = log
  end

  def self.poll_interval=(interval)
    self.options[:poll_interval] = interval
  end

end

require 'sidekiq/extensions/class_methods'
require 'sidekiq/extensions/action_mailer'
require 'sidekiq/extensions/active_record'
require 'sidekiq/rails' if defined?(::Rails::Engine)
