# frozen_string_literal: true

require 'socket'
require_relative 'base'

module WS2XX
  module Broadcasters
    # TCP broadcaster: sends messages to a TCP endpoint
    class TCP < Base
      attr_reader :remote_host, :remote_port

      def initialize(remote_host = ENV['TCP_HOST'] || '127.0.0.1', remote_port = ENV['TCP_PORT'] || 5000)
        super()
        @remote_host = remote_host
        @remote_port = remote_port.to_i
        @socket = nil
      end

      def broadcast(message)
        Async do
          ensure_socket!

          @socket.write(message)
          Console.logger.info "[TCP] Sent #{message.bytesize} bytes to #{@remote_host}:#{@remote_port}"
        rescue StandardError => e
          Console.logger.error "[TCP] Error sending message: #{e.message}"
          @socket&.close
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
          @socket = TCPSocket.new(@remote_host, @remote_port)
          Console.logger.info "[TCP] Connected to #{@remote_host}:#{@remote_port}"
        rescue StandardError => e
          Console.logger.error "[TCP] Connection error: #{e.message}"
          raise
        end
      end
    end
  end
end
