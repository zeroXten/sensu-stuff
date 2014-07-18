#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'multi_json'
require 'rest_client'
require 'net/http'
require 'time'

class BaggageHandler < Sensu::Handler

  def handle
    case @event['action'].to_s
    when 'create'
      status = 'ALERT'
    when 'flapping'
      status = 'FLAPPING'
    when 'resolve'
      status = 'RESOLVED'
    else
      status = 'OTHER'
    end

    from = 'Sensu Event'
    subject = "#{status} #{@event['check']['name']} #{@event['client']['name']}"
    body = <<-EOF

#{@event['check']['output'].chomp}

status:           #{status}
client:           #{@event['client']['name']} (#{@event['client']['address']})
issued:           #{Time.at(@event['check']['issued'])}

command:          #{@event['check']['command']}
interval:         #{@event['check']['interval']}
occurrences:      #{@event['occurrences']}
kthnxbye,
Ops
EOF

    if settings['baggage']['baggage_id'].downcase == 'test'
      puts subject
    else
      resp = RestClient.get "https://api.baggage.io/send/#{settings['baggage']['baggage_id']}", {:params => {:token => settings['baggage']['baggage_email_token'], :subject => subject, :body => body, :from => from}}
      puts resp.code
    end
  end

end
