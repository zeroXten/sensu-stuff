require 'multi_json'
require 'rest_client'

module Sensu::Extension
  class Baggage < Handler
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

    def run(event)
      if event[:suppressed]
        yield("suppressed", 0)
      else
        status = event[:action] == :create ? "PROBLEM" : "RESOLVED"
        handler_interval = event[:check][:handler_interval] ? event[:check][:handler_interval] : 'none'

        from = 'Sensu Event'
        subject = "#{status} #{event[:check][:output].chomp} on #{event[:client][:name]}"
        body = <<-EOF
status:           #{status}
output:           #{event[:check][:output].chomp}
client:           #{event[:client][:name]} (#{event[:client][:address]})
issued:           #{Time.at(event[:check][:issued])}
interval:         #{event[:check][:interval]}
handler interval: #{handler_interval}

kthnxbye,
Ops
        EOF

        if @settings[:baggage][:baggage_id].downcase == 'test'
          yield(subject, 0)
        else
          resp = RestClient.get "https://api.baggage.io/send/#{@settings[:baggage][:baggage_id]}", {:params => {:token => @settings[:baggage][:baggage_email_token], :subject => subject, :body => body, :from => from}}
          yield(resp.code.to_s, 0)
        end
      end
    end

    def stop
      yield
    end

  end
end
