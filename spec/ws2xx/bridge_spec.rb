# frozen_string_literal: true

require 'spec_helper'

describe WS2XX::Bridge, :aggregate_failures do
  subject(:bridge) { described_class.new(config) }

  let(:config) do
    {
      ws_url: 'wss://example.com/stream',
      ws_api_key: 'test-key',
      destinations: [
        { type: 'udp', host: '127.0.0.1', port: 5000 }
      ]
    }
  end

  describe '#initialize' do
    it 'forwards reconnect_on_error to WebSocketClient' do
      allow(WS2XX::WebSocketClient).to receive(:new).and_call_original

      described_class.new(config)

      expect(WS2XX::WebSocketClient).to have_received(:new).with(
        hash_including(
          url: config[:ws_url],
          api_key: config[:ws_api_key],
          reconnect_on_error: false
        )
      )
    end

    it 'creates a WebSocketClient with config' do
      expect(bridge.instance_variable_get(:@ws_client))
        .to be_instance_of(WS2XX::WebSocketClient)
    end

    it 'creates a Broadcasters::Builder' do
      expect(bridge.instance_variable_get(:@broadcaster_builder))
        .to be_instance_of(WS2XX::Broadcasters::Builder)
    end

    it 'sets config' do
      expect(bridge.config).to eq(config)
    end

    it 'initializes broadcaster to nil' do
      expect(bridge.broadcaster).to be_nil
    end

    it 'initializes error_code to 0' do
      expect(bridge.error_code).to eq(0)
    end
  end

  describe '#setup_components' do
    it 'builds broadcaster from config destinations' do
      builder = bridge.instance_variable_get(:@broadcaster_builder)
      allow(builder).to receive(:build).and_return(instance_double(WS2XX::Broadcasters::Base))

      bridge.setup_components

      expect(builder).to have_received(:build).with(config[:destinations])
      expect(bridge.instance_variable_get(:@broadcaster)).not_to be_nil
    end
  end

  describe '#run' do
    let(:mock_broadcaster) { instance_double(WS2XX::Broadcasters::Base) }
    let(:mock_ws_client) { bridge.instance_variable_get(:@ws_client) }

    it 'runs WebSocketClient within Async block' do
      allow(mock_ws_client).to receive(:run)
      mock_broadcaster = instance_spy(WS2XX::Broadcasters::Base)
      bridge.instance_variable_set(:@broadcaster, mock_broadcaster)

      Async do
        bridge.run
      end

      expect(mock_ws_client).to have_received(:run).with(mock_broadcaster)
    end

    it 'calls shutdown after run completes' do
      allow(mock_ws_client).to receive(:run).and_raise(StandardError)
      mock_broadcaster = instance_spy(WS2XX::Broadcasters::Base)
      bridge.instance_variable_set(:@broadcaster, mock_broadcaster)

      Async do
        bridge.run
      rescue StandardError
        # error is expected
      end

      expect(mock_broadcaster).to have_received(:close)
      expect(bridge.instance_variable_get(:@broadcaster)).to be_nil
    end
  end

  describe '#start' do
    let(:mock_ws_client) { bridge.instance_variable_get(:@ws_client) }

    before do
      allow(mock_ws_client).to receive(:run)
    end

    it 'orchestrates setup_components, run, and shutdown' do
      call_order = []
      mock_broadcaster = instance_spy(WS2XX::Broadcasters::Base)

      allow_any_instance_of(WS2XX::Broadcasters::Builder).to receive(:build) do
        call_order << :build
        mock_broadcaster
      end

      allow(mock_ws_client).to receive(:run) do
        call_order << :run
      end

      Async do
        bridge.start
      end

      # Verify the sequence and cleanup
      expect(call_order).to include(:build, :run)
      expect(mock_broadcaster).to have_received(:close)
      expect(bridge.broadcaster).to be_nil
    end

    it 'calls setup_components before run' do
      call_order = []
      mock_broadcaster = instance_spy(WS2XX::Broadcasters::Base)

      allow_any_instance_of(WS2XX::Broadcasters::Builder).to receive(:build) do
        call_order << :build
        mock_broadcaster
      end

      allow(mock_ws_client).to receive(:run) do
        call_order << :run
      end

      Async do
        bridge.start
      end

      expect(call_order).to include(:build)
      expect(call_order.index(:build)).to be < call_order.index(:run)
    end
  end

  describe '#shutdown' do
    let(:mock_broadcaster) { instance_double(WS2XX::Broadcasters::UDP) }

    it 'closes the broadcaster' do
      allow(mock_broadcaster).to receive(:close)
      bridge.instance_variable_set(:@broadcaster, mock_broadcaster)

      bridge.shutdown

      expect(mock_broadcaster).to have_received(:close)
      expect(bridge.instance_variable_get(:@broadcaster)).to be_nil
    end

    it 'handles nil broadcaster gracefully' do
      bridge.instance_variable_set(:@broadcaster, nil)

      expect { bridge.shutdown }.not_to raise_error
      expect(bridge.instance_variable_get(:@broadcaster)).to be_nil
    end

    it 'clears ws_server reference' do
      bridge.instance_variable_set(:@ws_server, 'some_server')

      bridge.shutdown

      expect(bridge.instance_variable_get(:@ws_server)).to be_nil
    end
  end

  describe 'attribute readers' do
    let(:mock_broadcaster) { instance_double(WS2XX::Broadcasters::UDP) }

    it 'has config reader' do
      expect(bridge.config).to eq(config)
    end

    it 'has ws_server reader' do
      bridge.instance_variable_set(:@ws_server, 'server')
      expect(bridge.ws_server).to eq('server')
    end

    it 'has broadcaster reader' do
      bridge.instance_variable_set(:@broadcaster, mock_broadcaster)
      expect(bridge.broadcaster).to eq(mock_broadcaster)
    end

    it 'has error_code reader' do
      bridge.instance_variable_set(:@error_code, 1)
      expect(bridge.error_code).to eq(1)
    end
  end
end
