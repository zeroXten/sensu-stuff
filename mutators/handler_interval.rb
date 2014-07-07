require 'multi_json'
require 'redis'
require 'time'

module Sensu::Extension
  class HandlerInterval < Mutator

    ONE_DAY = 60 * 60 * 24

    def post_init
      @redis = Redis.new(@settings[:handler_interval][:redis])
    end

    def definition
      {
        type: 'extension',
        name: 'handler_interval'
      }
    end

    def name
      definition[:name]
    end

    def description
      'Implements refresh functionality for handlers'
    end

    def run(event, &block)
      expire_period = ONE_DAY

      if event[:check][:handler_interval]
        key = "#{event[:client][:name]}/#{event[:check][:name]}"
        if event[:action] == :create
          now = Time.now
          if @redis.exists(key)
            last_seen = Time.parse(MultiJson.load(@redis.get(key), :symbolize_keys => true)[:last_sent])
            interval = event[:check][:handler_interval].to_i
            if now - last_seen < interval
              # Too soon
              event[:suppressed] = true
              event[:suppressed_state] = 'too soon'
            else
              # Time to send again
              @redis.set(key, MultiJson.dump({:last_sent => now}))
              @redis.expire(key, expire_period)
              event[:suppressed] = false
              event[:suppressed_state] = 'interval expired'
            end
          else
            # Never seen it before, send and start tracking
            @redis.set(key, MultiJson.dump({:last_sent => now}))
            @redis.expire(key, expire_period)
            event[:suppressed] = false
            event[:suppressed_state] = 'first seen'
          end
        else
          # Has been resolved, clean up and output
          @redis.del(key) if @redis.exists(key)
          event[:suppressed] = false
          event[:suppressed_state] = 'action is not create'
        end
      end
      block.call(event, 0)
    end

  end
end
