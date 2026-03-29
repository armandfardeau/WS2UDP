# frozen_string_literal: true

require 'optparse'

module WS2XX
  # CLI argument parser for WS2XX bridge
  # rubocop:disable Metrics/ClassLength
  class CLI
    attr_reader :options

    def initialize
      @options = {
        ws_url: nil,
        ws_api_key: nil,
        destinations: [],
        reconnect_on_error: false,
        filter_message_types: %w[PositionReport ShipStaticData SafetyBroadcastMessage],
        filters_ship_mmsis: []
      }
    end

    def parse(args)
      parser.parse!(args)
      self
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = 'Usage: ws2xx [options]'
        opts.separator ''

        parse_ws_configuration(opts)
        parse_destination_configuration(opts)
        parse_options(opts)

        opts.separator 'Common options:'

        opts.on_tail('-h', '--help', 'Show this message') do
          Console.logger.info opts
          exit(0)
        end

        opts.on_tail('--version', 'Show version') do
          Console.logger.info "WS2XX v#{WS2XX::VERSION}"
          exit(0)
        end
      end
    end

    def validate!
      if @options[:destinations].empty? && !@options[:ws_enabled]
        raise 'At least one destination or WebSocket destination must be configured'
      end

      @options[:destinations].each do |dest|
        raise 'Destination port must be between 1 and 65535' unless (1..65_535).include?(dest[:port])
      end

      self
    end

    def to_h
      @options.dup
    end

    private

    def parse_ws_configuration(opts)
      opts.separator 'WebSocket Configuration:'

      opts.on('--ws-url HOST', String, "WebSocket server URL (default: #{@options[:ws_url]})") do |h|
        @options[:ws_url] = h
      end

      opts.on('--ws-api-key KEY', String, "WebSocket API key (default: #{@options[:ws_api_key]})") do |k|
        @options[:ws_api_key] = k
      end

      opts.on(
        '--ws-bounding-boxes BOXES',
        String,
        "WebSocket bounding boxes (format: minLat,minLon,maxLat,maxLon; multiple boxes separated by '|')"
      ) do |boxes|
        @options[:bounding_boxes] = [
          boxes.split('|').map do |box|
            box.split(',').map(&:to_f)
          end
        ]
      end

      opts.separator ''
    end

    def parse_destination_configuration(opts)
      opts.separator 'Destination Configuration (can be used multiple times):'

      opts.on(
        '--destination TYPE://HOST:PORT',
        String,
        'Add a destination (e.g., udp://127.0.0.1:5000, tcp://127.0.0.1:6000)'
      ) do |destination|
        @options[:destinations] << parse_destination(destination)
      end

      opts.separator ''
    end

    # Parse destination URI: "type://host:port"
    def parse_destination(uri_str)
      raise "Invalid destination format: #{uri_str}. Expected: type://host:port" unless uri_str.include?('://')

      type, rest = uri_str.split('://')
      host, port = rest.split(':')

      {
        type: type.downcase,
        host: host,
        port: port.to_i
      }
    end

    def parse_options(opts)
      opts.separator 'Other options:'
      message_types_help = 'Comma-separated list of message types to filter '
      message_types_help += '(default: PositionReport, ShipStaticData, SafetyBroadcastMessage)'

      opts.on('--message-types TYPES', String, message_types_help) do |types|
        @options[:filter_message_types] = types.split(',').map(&:strip)
      end

      opts.on('--mmsis MMSIS', String, 'Comma-separated list of ship MMSIs to filter (default: [])') do |mmsis|
        @options[:filters_ship_mmsis] = mmsis.split(',').map(&:strip)
      end

      opts.on(
        '--reconnect-on-error',
        'Reconnect indefinitely when WebSocket errors occur'
      ) do
        @options[:reconnect_on_error] = true
      end

      opts.separator ''
    end
    # rubocop:enable Metrics/ClassLength
  end
end
