# frozen_string_literal: true

require 'spec_helper'

describe WS2XX::CLI, :aggregate_failures do
  subject(:cli) { described_class.new }

  describe '#initialize' do
    let(:expected_defaults) do
      {
        ws_url: nil,
        ws_api_key: nil,
        destinations: [],
        reconnect_on_error: false,
        filter_message_types: %w[PositionReport ShipStaticData SafetyBroadcastMessage],
        filters_ship_mmsis: []
      }
    end

    it 'sets default options' do
      expect(cli.options).to eq(expected_defaults)
    end
  end

  describe '#parse' do
    it 'returns self for method chaining' do
      result = cli.parse([])
      expect(result).to be(cli)
    end

    context 'when WebSocket configuration is provided' do
      it 'parses --ws-url' do
        cli.parse(['--ws-url', 'wss://example.com/stream'])
        expect(cli.options[:ws_url]).to eq('wss://example.com/stream')
      end

      it 'parses --ws-api-key' do
        cli.parse(['--ws-api-key', 'secret-key'])
        expect(cli.options[:ws_api_key]).to eq('secret-key')
      end

      it 'parses --ws-bounding-boxes with single box' do
        cli.parse(['--ws-bounding-boxes', '40.7,-74.0,40.8,-73.9'])

        expected = [[[40.7, -74.0, 40.8, -73.9]]]
        expect(cli.options[:bounding_boxes]).to eq(expected)
      end

      it 'parses --ws-bounding-boxes with multiple boxes' do
        cli.parse(['--ws-bounding-boxes', '40.7,-74.0,40.8,-73.9|41.0,-75.0,41.1,-74.9'])

        expected = [[[40.7, -74.0, 40.8, -73.9], [41.0, -75.0, 41.1, -74.9]]]
        expect(cli.options[:bounding_boxes]).to eq(expected)
      end
    end

    context 'when destination configuration is provided' do
      it 'parses single UDP destination' do
        cli.parse(['--destination', 'udp://127.0.0.1:5000'])
        expect(cli.options[:destinations]).to include(type: 'udp', host: '127.0.0.1', port: 5000)
      end

      it 'parses single TCP destination' do
        cli.parse(['--destination', 'tcp://192.168.1.1:6000'])
        expect(cli.options[:destinations]).to include(type: 'tcp', host: '192.168.1.1', port: 6000)
      end

      it 'parses multiple destinations' do
        cli.parse(['--destination', 'udp://127.0.0.1:5000', '--destination', 'tcp://192.168.1.1:6000'])
        expect(cli.options[:destinations].size).to eq(2)
        expect(cli.options[:destinations][0]).to include(type: 'udp')
        expect(cli.options[:destinations][1]).to include(type: 'tcp')
      end

      it 'parses destination with hostname' do
        cli.parse(['--destination', 'udp://example.com:5000'])
        expect(cli.options[:destinations]).to include(type: 'udp', host: 'example.com', port: 5000)
      end
    end

    context 'when option combinations are provided' do
      let(:all_options_args) do
        [
          '--ws-url', 'wss://example.com/stream',
          '--ws-api-key', 'my-key',
          '--ws-bounding-boxes', '40.7,-74.0,40.8,-73.9',
          '--destination', 'udp://127.0.0.1:5000',
          '--destination', 'tcp://192.168.1.1:6000'
        ]
      end

      it 'parses all WebSocket and destination options together' do
        cli.parse(all_options_args)
        expect(cli.options[:ws_url]).to eq('wss://example.com/stream')
        expect(cli.options[:ws_api_key]).to eq('my-key')
        expect(cli.options[:bounding_boxes]).to eq([[[40.7, -74.0, 40.8, -73.9]]])
        expect(cli.options[:destinations].size).to eq(2)
      end

      it 'parses --reconnect-on-error' do
        cli.parse(['--reconnect-on-error'])
        expect(cli.options[:reconnect_on_error]).to be(true)
      end
    end
  end

  describe '#validate!' do
    it 'returns self for method chaining' do
      cli.parse(['--destination', 'udp://127.0.0.1:5000'])
      result = cli.validate!
      expect(result).to be(cli)
    end

    context 'when the configurations are valid' do
      it 'passes with valid destination configuration' do
        cli.parse(['--destination', 'udp://127.0.0.1:5000'])

        expect { cli.validate! }.not_to raise_error
      end

      it 'passes with multiple valid destinations' do
        cli.parse([
                    '--destination', 'udp://127.0.0.1:5000',
                    '--destination', 'tcp://192.168.1.1:6000'
                  ])

        expect { cli.validate! }.not_to raise_error
      end
    end

    context 'when validating ports' do
      it 'raises error if port is too low' do
        cli.instance_variable_set(:@options, {
                                    destinations: [{ type: 'udp', host: '127.0.0.1', port: 0 }],
                                    ws_enabled: false
                                  })

        expect { cli.validate! }.to raise_error('Destination port must be between 1 and 65535')
      end

      it 'raises error if port is too high' do
        cli.instance_variable_set(:@options, {
                                    destinations: [{ type: 'udp', host: '127.0.0.1', port: 65_536 }],
                                    ws_enabled: false
                                  })

        expect { cli.validate! }.to raise_error('Destination port must be between 1 and 65535')
      end

      it 'accepts port 1 (minimum)' do
        cli.instance_variable_set(:@options, {
                                    destinations: [{ type: 'udp', host: '127.0.0.1', port: 1 }],
                                    ws_enabled: false
                                  })

        expect { cli.validate! }.not_to raise_error
      end

      it 'accepts port 65535 (maximum)' do
        cli.instance_variable_set(:@options, {
                                    destinations: [{ type: 'udp', host: '127.0.0.1', port: 65_535 }],
                                    ws_enabled: false
                                  })

        expect { cli.validate! }.not_to raise_error
      end
    end

    context 'when configurations are invalid' do
      it 'raises error if no destinations and no WebSocket' do
        cli.instance_variable_set(:@options, { destinations: [], ws_enabled: false })
        expect { cli.validate! }.to raise_error('At least one destination or WebSocket destination must be configured')
      end
    end
  end

  describe '#to_h' do
    it 'returns a hash of options' do
      cli.parse(['--destination', 'udp://127.0.0.1:5000'])

      result = cli.to_h

      expect(result).to be_a(Hash)
      expect(result[:destinations]).to include(type: 'udp', host: '127.0.0.1', port: 5000)
    end

    it 'returns a duplicate of options (not reference)' do
      cli.parse(['--destination', 'udp://127.0.0.1:5000'])

      hash1 = cli.to_h
      hash1[:destinations] = []
      hash2 = cli.to_h

      expect(hash2[:destinations]).not_to be_empty
    end
  end

  describe '#parser' do
    it 'returns an OptionParser instance' do
      parser = cli.parser
      expect(parser).to be_instance_of(OptionParser)
    end

    it 'caches the parser' do
      parser1 = cli.parser
      parser2 = cli.parser

      expect(parser1).to be(parser2)
    end

    it 'has proper banner' do
      parser = cli.parser
      expect(parser.banner).to include('Usage: ws2xx [options]')
    end
  end
end
