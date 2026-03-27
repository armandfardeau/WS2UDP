# frozen_string_literal: true

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'
require 'json'

require_relative 'message'
module WS2XX
  # WebSocket client: connects to WS server, subscribes to messages, and broadcasts them
  class WebSocketClient
    def initialize(url:, api_key:, retry_attempts: 3, options: {})
      @url = url
      @api_key = api_key
      @retry_attempts = retry_attempts
      @options = options
    end

    def run(broadcaster)
      Async do
        Console.logger.info "[WS CLIENT] Connecting to #{@url}..."
        stream_messages(broadcaster)
      rescue EOFError => e
        Console.logger.warn "[WS CLIENT] Connection closed by server: #{e.message}"
      rescue StandardError => e
        Console.logger.error "[WS CLIENT] Error: #{e.class} - #{e.message}"
        raise
      end
    end

    private

    def stream_messages(broadcaster)
      Async::WebSocket::Client.connect(endpoint) do |connection|
        susbcribe_to_messages(connection)

        while (message = connection.read)
          process_message(message, broadcaster)
        end
      end
    end

    def process_message(raw_message, broadcaster)
      message = Message.parse(raw_message)
      if message.valid? && !message.to_nmea.nil?
        broadcaster.broadcast(message.to_nmea)
        Console.logger.info "[WS CLIENT] Broadcasted message: #{message.to_json}"
      else
        Console.logger.warn "[WS CLIENT] Invalid message received: #{message.errors.join(', ')}"
      end
    end

    def endpoint
      @endpoint ||= Async::HTTP::Endpoint.parse(@url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
    end

    def susbcribe_to_messages(connection)
      subscription_message = {
        'ApiKey' => @api_key,
        'BoundingBoxes' => @options.fetch(:bounding_boxes) { raise 'Bounding boxes are required' },
        'FiltersShipMMSI' => @options.fetch(:filters_ship_mmsis, []),
        'FilterMessageTypes' => @options.fetch(:filter_message_types, [])
      }

      Console.logger.info "[WS CLIENT] Subscribing with message: #{subscription_message}"
      connection.write(Protocol::WebSocket::TextMessage.generate(subscription_message))
    end
  end
end
