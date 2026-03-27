# frozen_string_literal: true

require 'ais_to_nmea'
require 'json'

module WS2XX
  # Represents a WebSocket message
  class Message
    attr_reader :raw_message, :parsed_message

    def initialize(raw_message)
      @raw_message = raw_message
      @data = {}
      @errors = []
    end

    def self.parse(raw_message)
      instance = new(raw_message)
      instance.parse
      instance.validate!

      instance
    end

    def parse
      data = from_json(@raw_message.to_str)
      return @data = {} if data.nil?

      parsed = extract_payload(data)
      if parsed.nil? || parsed.empty?
        add_error('Message field is missing or invalid')
        @data = {}
      else
        @data = parsed
      end
    end

    def to_nmea
      return @to_nmea if defined?(@to_nmea)

      @to_nmea = AisToNmea.to_nmea(@data)
    rescue AisToNmea::Error => e
      add_error("NMEA conversion error: #{e.message}")
      nil
    end

    def to_json(*_args)
      @data.to_json
    end

    def valid?
      @errors.empty?
    end

    def errors
      @errors.dup
    end

    def add_error(error)
      @errors << error
    end

    def validate!
      return unless @parsed_message.nil? || @parsed_message.empty?

      add_error('Message is empty')      
    end

    def from_json(json_str)
      @parsed_message = JSON.parse(json_str)
    rescue JSON::ParserError => e
      add_error("JSON parsing error: #{e.message}")
      nil
    end

    # Accept both AIS stream format (`{"Message": {"Type": {...}}}`)
    # and plain payload hashes used by tests/integrations.
    def extract_payload(data)
      message = data['Message']
      return data if message.nil?
      return message.each_value.first if message.respond_to?(:each_value)

      nil
    end
  end
end
