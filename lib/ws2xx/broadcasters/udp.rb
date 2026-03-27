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
        socket = ensure_socket!
        raise 'UDP socket is not available' if socket.nil?

        socket.send(message, 0, @remote_host, @remote_port)
        Console.logger.info "[UDP] Sent #{message.bytesize} bytes to #{@remote_host}:#{@remote_port}"
      rescue StandardError => e
        Console.logger.error "[UDP] Error sending message: #{e.message}"
        close
      end

      def close
        @socket&.close
        @socket = nil
      end

      private

      def ensure_socket!
        @ensure_socket ||= UDPSocket.new
      end
    end
  end
end
