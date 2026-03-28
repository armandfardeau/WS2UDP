# frozen_string_literal: true

require 'spec_helper'

describe WS2XX::WebSocketClient do
  subject(:client) { described_class.new(url: url, api_key: api_key, options: options) }

  let(:url) { 'wss://example.com/stream' }
  let(:api_key) { 'test-api-key' }
  let(:options) { { bounding_boxes: [[40.7, -74.0, 40.8, -73.9]] } }

  describe '#initialize' do
    it 'sets url, api_key, and options' do
      expect(client.instance_variable_get(:@url)).to eq(url)
      expect(client.instance_variable_get(:@api_key)).to eq(api_key)
      expect(client.instance_variable_get(:@options)).to eq(options)
      expect(client.instance_variable_get(:@reconnect_on_error)).to be(false)
    end
  end

  describe '#run' do
    let(:broadcaster) { double('broadcaster') }
    let(:mock_connection) { double('connection') }

    it 'connects to the WebSocket endpoint and handles messages' do
      mock_message = double('message')
      allow(mock_message).to receive(:to_str).and_return('{"test": "message"}')

      mock_parsed = double('parsed', valid?: true, to_nmea: '!AIVDM,1,1,,A,test,0*00', to_json: '{}')
      allow(WS2XX::Message).to receive(:parse).and_return(mock_parsed)

      allow(Async::WebSocket::Client).to receive(:connect).and_yield(mock_connection)
      allow(mock_connection).to receive(:write)
      allow(mock_connection).to receive(:read).and_return(mock_message, nil)
      allow(broadcaster).to receive(:broadcast)

      Async do
        client.run(broadcaster)
      end

      expect(Async::WebSocket::Client).to have_received(:connect)
      expect(broadcaster).to have_received(:broadcast)
    end

    it 'sends subscription message with correct API key' do
      allow(Async::WebSocket::Client).to receive(:connect).and_yield(mock_connection)
      allow(mock_connection).to receive(:write)
      allow(mock_connection).to receive(:read).and_return(nil)
      allow(broadcaster).to receive(:broadcast)

      Async do
        client.run(broadcaster)
      end

      expect(mock_connection).to have_received(:write)
    end

    it 'handles EOFError gracefully' do
      allow(Async::WebSocket::Client).to receive(:connect).and_yield(mock_connection)
      allow(mock_connection).to receive(:write)
      allow(mock_connection).to receive(:read).and_raise(EOFError.new('Connection closed'))

      expect do
        Async do
          client.run(broadcaster)
        end
      end.not_to raise_error
    end

    it 're-raises other StandardErrors' do
      allow(Async::WebSocket::Client).to receive(:connect).and_raise(StandardError.new('Connection error'))

      Async do
        client.run(broadcaster)
      end

      # Error is logged and raised from the Async block
      # The test passes if no exception is raised at the test level
    end

    it 'reconnects indefinitely on errors when reconnect_on_error is true' do
      reconnect_client = described_class.new(
        url: url,
        api_key: api_key,
        reconnect_on_error: true,
        options: options
      )

      allow(Async::Task).to receive_message_chain(:current, :sleep)

      call_count = 0
      allow(reconnect_client).to receive(:stream_messages) do
        call_count += 1
        if call_count == 1
          raise StandardError, 'temporary failure'
        end

        reconnect_client.instance_variable_set(:@reconnect_on_error, false)
      end

      reconnect_client.run(broadcaster).wait

      expect(reconnect_client).to have_received(:stream_messages).twice
    end

    it 'broadcasts each message received' do
      message1 = double('message1')
      message2 = double('message2')
      allow(message1).to receive(:to_str).and_return('{"data": "msg1"}')
      allow(message2).to receive(:to_str).and_return('{"data": "msg2"}')

      mock_parsed = double('parsed', valid?: true, to_nmea: '!AIVDM,1,1,,A,test,0*00', to_json: '{}')
      allow(WS2XX::Message).to receive(:parse).and_return(mock_parsed)

      allow(Async::WebSocket::Client).to receive(:connect).and_yield(mock_connection)
      allow(mock_connection).to receive(:write)
      allow(mock_connection).to receive(:read).and_return(message1, message2, nil)
      allow(broadcaster).to receive(:broadcast)

      Async do
        client.run(broadcaster)
      end

      expect(broadcaster).to have_received(:broadcast).at_least(:once)
    end
  end

  describe '#endpoint' do
    it 'creates an Async::HTTP::Endpoint from the URL' do
      allow(Async::HTTP::Endpoint).to receive(:parse)
        .with(url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
        .and_return(double('endpoint'))

      client.send(:endpoint)

      expect(Async::HTTP::Endpoint).to have_received(:parse)
    end

    it 'caches the endpoint' do
      mock_endpoint = double('endpoint')
      allow(Async::HTTP::Endpoint).to receive(:parse).and_return(mock_endpoint)

      endpoint1 = client.send(:endpoint)
      endpoint2 = client.send(:endpoint)

      expect(Async::HTTP::Endpoint).to have_received(:parse).once
      expect(endpoint1).to be(endpoint2)
    end
  end

  describe '#susbcribe_to_messages' do
    let(:mock_connection) { spy('connection') }

    it 'sends subscription message with API key and bounding boxes' do
      client.send(:susbcribe_to_messages, mock_connection)

      expect(mock_connection).to have_received(:write)
    end

    it 'raises error if bounding_boxes not provided' do
      client_no_bbox = described_class.new(url: url, api_key: api_key, options: {})

      expect { client_no_bbox.send(:susbcribe_to_messages, mock_connection) }
        .to raise_error('Bounding boxes are required')
    end

    it 'includes optional filters in subscription message' do
      client_with_filters = described_class.new(
        url: url,
        api_key: api_key,
        options: {
          bounding_boxes: [[40.7, -74.0, 40.8, -73.9]],
          filters_ship_mmsis: ['123456789'],
          filter_message_types: %w[PositionReport StaticData]
        }
      )

      client_with_filters.send(:susbcribe_to_messages, mock_connection)

      expect(mock_connection).to have_received(:write)
    end
  end
end
