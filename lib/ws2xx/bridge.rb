# frozen_string_literal: true

require_relative 'broadcasters/builder'
require_relative 'websocket_client'

module WS2XX
  # Bridge orchestrator: manages the lifecycle and composition of bridge components
  class Bridge
    attr_reader :config, :ws_server, :destinations

    def initialize(config)
      @config = config
      @ws_client = WebSocketClient.new(url: @config[:ws_url], api_key: @config[:ws_api_key], options: @config)
      @broadcaster_builder = Broadcasters::Builder.new
      @broadcaster = nil
    end

    # Setup and start the bridge
    def start
      setup_components
      print_startup_info
      run
    end

    # Setup all bridge components
    def setup_components
      Console.logger.info '[BRIDGE] Setting up components...'
      @broadcaster = @broadcaster_builder.build(@config[:destinations])
    end

    # Run the bridge (blocks until shutdown)
    def run
      Async do
        @ws_client.run(@broadcaster)
      end
    ensure
      shutdown
    end

    # Graceful shutdown
    def shutdown
      Console.logger.info "\n[BRIDGE] Shutting down..."
      @broadcaster&.close
      @ws_server = nil
      @broadcaster = nil
    end

    private

    def print_startup_info
      Console.logger.info "WS2XX Bridge v#{WS2XX::VERSION}"
      Console.logger.info "WebSocket: #{@config[:ws_url]}"

      @config[:destinations].each do |dest|
        Console.logger.info "Destination: #{dest[:type].upcase}://#{dest[:host]}:#{dest[:port]}"
      end
    end
  end
end
