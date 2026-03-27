# frozen_string_literal: true

module WS2XX
  module Broadcasters
    # Composite destination strategy: chains multiple destination handlers
    class Composite < Broadcasters::Base
      def initialize(broadcasters = [])
        super()
        @broadcasters = broadcasters
      end

      def add_broadcaster(broadcaster)
        @broadcasters << broadcaster
        self
      end

      def broadcast(message)
        @broadcasters.each do |broadcaster|
          broadcaster.broadcast(message)
        rescue StandardError => e
          Console.logger.error "[COMPOSITE] Broadcaster error: #{e.message}"
        end
      end

      def close
        @broadcasters.each { |broadcaster| broadcaster.close if broadcaster.respond_to?(:close) }
      end
    end
  end
end
