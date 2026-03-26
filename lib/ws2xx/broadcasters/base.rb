# frozen_string_literal: true

module WS2XX
  module Broadcasters
    # Broadcaster strategy interface: defines how to broadcast a message
    class Base
      def broadcast(message)
        raise NotImplementedError, 'Subclass must implement broadcast(message)'
      end

      def close
        # Optional cleanup
      end
    end
  end
end
