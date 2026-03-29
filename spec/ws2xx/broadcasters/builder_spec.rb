# frozen_string_literal: true

require 'spec_helper'
require 'ws2xx/broadcasters/builder'

describe WS2XX::Broadcasters::Builder, :aggregate_failures do
  subject(:builder) { described_class.new }

  describe '#build' do
    context 'with single UDP destination' do
      it 'returns a UDP broadcaster' do
        destinations = [{ type: 'udp', host: '127.0.0.1', port: 5000 }]

        broadcaster = builder.build(destinations)

        expect(broadcaster).to be_instance_of(WS2XX::Broadcasters::UDP)
        expect(broadcaster.remote_host).to eq('127.0.0.1')
        expect(broadcaster.remote_port).to eq(5000)
      end
    end

    context 'with single TCP destination' do
      it 'returns a TCP broadcaster' do
        destinations = [{ type: 'tcp', host: '192.168.1.1', port: 6000 }]

        broadcaster = builder.build(destinations)

        expect(broadcaster).to be_instance_of(WS2XX::Broadcasters::TCP)
        expect(broadcaster.remote_host).to eq('192.168.1.1')
        expect(broadcaster.remote_port).to eq(6000)
      end
    end

    context 'with multiple destinations' do
      it 'returns a Composite broadcaster' do
        destinations = [
          { type: 'udp', host: '127.0.0.1', port: 5000 },
          { type: 'tcp', host: '192.168.1.1', port: 6000 }
        ]

        broadcaster = builder.build(destinations)

        expect(broadcaster).to be_instance_of(WS2XX::Broadcasters::Composite)
        broadcasters = broadcaster.instance_variable_get(:@broadcasters)
        expect(broadcasters.size).to eq(2)
        expect(broadcasters[0]).to be_instance_of(WS2XX::Broadcasters::UDP)
        expect(broadcasters[1]).to be_instance_of(WS2XX::Broadcasters::TCP)
      end
    end

    context 'with symbol type keys' do
      it 'handles symbol type keys' do
        destinations = [{ type: :udp, host: '127.0.0.1', port: 5000 }]

        broadcaster = builder.build(destinations)

        expect(broadcaster).to be_instance_of(WS2XX::Broadcasters::UDP)
      end
    end

    context 'validation errors' do
      it 'raises error if destinations is not an array' do
        expect { builder.build('not an array') }.to raise_error(ArgumentError, 'Destinations must be an array')
      end

      it 'raises error if destinations array is empty' do
        expect { builder.build([]) }.to raise_error(ArgumentError, 'At least one destination must be specified')
      end

      it 'raises error for unsupported destination type' do
        destinations = [{ type: 'http', host: '127.0.0.1', port: 8000 }]

        expect { builder.build(destinations) }.to raise_error('Unsupported destination type: http')
      end
    end
  end
end
