require 'multi_json'
require 'rest_client'
require 'net/http'
require 'sensu-plugin/utils'

module Sensu::Extension
  class Baggage < Handler
    include Sensu::Plugin::Utils

    def definition
      {
        type: 'extension',
        name: 'baggage',
  mutator: 'handler_interval'
      }
    end

    def name
      definition[:name]
    end

    def description
      'Send email using baggage.io'
    end

    # Using code from https://github.com/sensu/sensu-plugin/blob/master/lib/sensu-handler.rb
   def api_request(method, path, &blk)
      http = Net::HTTP.new(@settings['api']['host'], @settings['api']['port'])
      req = net_http_req_class(method).new(path)
      if @settings['api']['user'] && @settings['api']['password']
        req.basic_auth(@settings['api']['user'], @settings['api']['password'])
      end
      yield(req) if block_given?
      http.request(req)
    end

    def stash_exists?(path)
      api_request(:GET, '/stash' + path).code == '200'
    end

    def silenced?(event)
      stashes = [
        ['client', '/silence/' + event[:client][:name]],
        ['check', '/silence/' + event[:client][:name] + '/' + event[:check][:name]],
        ['check', '/silence/all/' + event[:check][:name]]
      ]
      stashes.each do |(scope, path)|
        begin
          timeout(2) do
            return true if stash_exists?(path)
          end
        rescue Timeout::Error
          raise 'timed out while attempting to query the sensu api for a stash'
        end
      end
      false
    end

    def run(event)
      if silenced?(event)
        yield('silenced', 0)
      elsif event[:suppressed]
        yield('suppressed', 0)
      else
        status = event[:action] == :create ? "PROBLEM" : "RESOLVED"
        handler_interval = event[:check][:handler_interval] ? event[:check][:handler_interval] : 'none'

        from = 'Sensu Event'
        subject = "#{status} #{event[:check][:name]} on #{event[:client][:name]}"
        body = <<-EOF

#{event[:check][:output].chomp}

status:           #{status}
client:           #{event[:client][:name]} (#{event[:client][:address]})
issued:           #{Time.at(event[:check][:issued])}

command:          #{event[:check][:command]}
interval:         #{event[:check][:interval]}
handler interval: #{handler_interval}

kthnxbye,
Ops
        EOF

        if @settings[:baggage][:baggage_id].downcase == 'test'
          yield(subject, 0)
        else
          resp = RestClient.get "https://api.baggage.io/send/#{@settings[:baggage][:baggage_id]}", {:params => {:token => @settings[:baggage][:baggage_email_token], :subject => subject, :body => body, :from => from}}
          yield(resp.code, 0)
        end
      end
    end

    def stop
      yield
    end

  end
end
