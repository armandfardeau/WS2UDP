# frozen_string_literal: true

require_relative 'ws2xx/cli'
require_relative 'ws2xx/bridge'

# Convert WebSocket messages to UDP/TCP and forward to configured endpoints
module WS2XX
  VERSION = '0.1.0'

  def self.run(args = ARGV)
    # Parse CLI arguments
    cli = CLI.new.parse(args).validate!
    config = cli.to_h

    # Create and start bridge with config
    bridge = Bridge.new(config)
    bridge.start
  end
end
