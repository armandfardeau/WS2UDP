# frozen_string_literal: true

require_relative 'broadcasters/builder'
require_relative 'websocket_client'

module WS2XX
  # Bridge orchestrator: manages the lifecycle and composition of bridge components
  class Bridge
    attr_reader :config, :ws_server, :broadcaster, :error_code

    def initialize(config)
      @config = config
      @ws_client = WebSocketClient.new(
        url: @config[:ws_url],
        api_key: @config[:ws_api_key],
        retry_attempts: @config.fetch(:retry_attempts, 3),
        reconnect_on_error: @config.fetch(:reconnect_on_error, false),
        options: @config.slice(:bounding_boxes, :filter_message_types, :filters_ship_mmsis)
      )
      @broadcaster_builder = Broadcasters::Builder.new
      @broadcaster = nil
      @error_code = 0
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
      @ws_client.run(@broadcaster)
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
