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
      @error_code = 0
      @retry_attempts = 3
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
      run_loop
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

    def run_loop
      Async do
        @ws_client.run(@broadcaster)
      rescue EOFError => e
        Console.logger.warn "[BRIDGE] WebSocket connection closed: #{e.message}"
        return abort_with_error('Maximum retry attempts reached. Shutting down.') unless @retry_attempts.positive?

        Console.logger.info '[BRIDGE] Retrying connection...'
        @retry_attempts -= 1
        run
      end
    end

    def abort_with_error(message)
      Console.logger.error "[BRIDGE] #{message}"
      @error_code = 1
    end

    def print_startup_info
      Console.logger.info "WS2XX Bridge v#{WS2XX::VERSION}"
      Console.logger.info "WebSocket: #{@config[:ws_url]}"

      @config[:destinations].each do |dest|
        Console.logger.info "Destination: #{dest[:type].upcase}://#{dest[:host]}:#{dest[:port]}"
      end
    end
  end
end
