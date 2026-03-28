# frozen_string_literal: true

require 'io/endpoint'
require_relative 'base'

module WS2XX
  module Broadcasters
    # UDP broadcaster: sends messages to a UDP endpoint
    class UDP < Base
      attr_reader :remote_host, :remote_port

      def initialize(remote_host = ENV['UDP_HOST'] || '127.0.0.1', remote_port = ENV['UDP_PORT'] || 5000)
        super()
        @remote_host = remote_host
        @remote_port = remote_port.to_i
        @endpoint = nil
      end

      def broadcast(message)
        endpoint = ensure_endpoint!
        endpoint.connect do |socket|
          socket.write(message)
        end
        Console.logger.info "[UDP] Sent #{message.bytesize} bytes to #{@remote_host}:#{@remote_port}"
      rescue StandardError => e
        Console.logger.error "[UDP] Error sending message: #{e.message}"
        close
      end

      def close
        endpoint = @endpoint
        @endpoint = nil
        endpoint&.close if endpoint.respond_to?(:close)
      end

      private

      def ensure_endpoint!
        @endpoint ||= IO::Endpoint.udp(@remote_host, @remote_port)
      end
    end
  end
end
