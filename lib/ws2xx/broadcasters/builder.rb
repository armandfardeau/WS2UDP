# frozen_string_literal: true

require_relative 'udp'
require_relative 'tcp'
require_relative 'composite'

module WS2XX
  module Broadcasters
    # Strategy builder/factory for composing broadcaster strategies
    class Builder
      BROADCASTER_MAPPING = {
        udp: Broadcasters::UDP,
        tcp: Broadcasters::TCP
      }.freeze

      def initialize
        @broadcaster_strategies = {}
      end

      def build(destinations = [])
        raise ArgumentError, 'Destinations must be an array' unless destinations.is_a?(Array)
        raise ArgumentError, 'At least one destination must be specified' if destinations.empty?

        if destinations.size == 1
          inferred_broadcaster_class(destinations.first)
        else
          composite = Broadcasters::Composite.new
          destinations.each { |destination| composite.add_broadcaster(inferred_broadcaster_class(destination)) }
          composite
        end
      end

      private

      def inferred_broadcaster_class(destination)
        klass = BROADCASTER_MAPPING.fetch(destination[:type].to_sym) do
          raise "Unsupported destination type: #{destination[:type]}"
        end

        klass.new(destination[:host], destination[:port])
      end
    end
  end
end
