# frozen_string_literal: true

require 'socket'
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
        @socket = nil
      end

      def broadcast(message)
        Async do
          ensure_socket!

          @socket.send(message, 0)
          Console.logger.info "[UDP] Sent #{message.bytesize} bytes to #{@remote_host}:#{@remote_port}"
        rescue StandardError => e
          Console.logger.error "[UDP] Error sending message: #{e.message}"
          @socket = nil
        end
      end

      def close
        @socket&.close
        @socket = nil
      end

      private

      def ensure_socket!
        return if @socket

        begin
          @socket = UDPSocket.new
          @socket.connect(@remote_host, @remote_port)
          Console.logger.info "[UDP] Connected to #{@remote_host}:#{@remote_port}"
        rescue StandardError => e
          Console.logger.error "[UDP] Connection error: #{e.message}"
          raise
        end
      end
    end
  end
end
