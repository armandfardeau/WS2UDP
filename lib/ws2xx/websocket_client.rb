# frozen_string_literal: true

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'
require 'json'

# WebSocket client: connects to WS server, subscribes to messages, and broadcasts them
class WebSocketClient
  def initialize(url:, api_key:, options: {})
    @url = url
    @api_key = api_key
    @options = options
  end

  def run(broadcaster)
    Console.logger.info "[WS CLIENT] Connecting to #{@url}..."

    stream_messages(broadcaster)
  rescue EOFError => e
    Console.logger.warn "[WS CLIENT] Connection closed: #{e.message}"
  rescue StandardError => e
    Console.logger.error "[WS CLIENT] Error: #{e.class} - #{e.message}"
    raise
  end

  private

  def stream_messages(broadcaster)
    Async::WebSocket::Client.connect(endpoint) do |connection|
      susbcribe_to_messages(connection)

      while (message = connection.read)
        message_data = message.to_str
        Console.logger.info "[WS CLIENT] Received message: #{message_data}..."
        broadcaster.broadcast(message_data)
      end

      Console.logger.info '[WS CLIENT] WebSocket connection closed by server'
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
      'FilterMessageTypes' => @options.fetch(:filter_message_types, ['PositionReport'])
    }

    Console.logger.info "[WS CLIENT] Subscribing with message: #{subscription_message}"
    connection.write(Protocol::WebSocket::TextMessage.generate(subscription_message))
  end
end
