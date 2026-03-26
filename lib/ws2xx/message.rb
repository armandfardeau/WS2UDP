# frozen_string_literal: true

module WS2XX
  # Represents a WebSocket message
  class Message
    attr_reader :raw_message, :parsed_message

    def initialize(raw_message)
      @raw_message = raw_message
      @parsed_message = nil
      @errors = []
    end

    def self.parse(raw_message)
      instance = new(raw_message)
      instance.parse
      instance.validate!

      instance
    end

    def parse
      @parsed_message = @raw_message.to_str
    end

    def valid?
      @errors.empty?
    end

    def errors
      @errors.dup
    end

    def validate!
      return unless @parsed_message.nil? || @parsed_message.empty?

      @errors << 'Message is empty'
      false
    end
  end
end
