# frozen_string_literal: true

require 'spec_helper'
require 'ws2xx/broadcasters/udp'

describe WS2XX::Broadcasters::UDP do
  subject(:broadcaster) { described_class.new(host, port) }

  let(:host) { '127.0.0.1' }
  let(:port) { 5000 }

  describe '#initialize' do
    it 'sets remote_host and remote_port from arguments' do
      expect(broadcaster.remote_host).to eq(host)
      expect(broadcaster.remote_port).to eq(port)
    end

    it 'uses environment variables as defaults' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('UDP_HOST').and_return('192.168.1.1')
      allow(ENV).to receive(:[]).with('UDP_PORT').and_return('6000')

      broadcaster = described_class.new
      expect(broadcaster.remote_host).to eq('192.168.1.1')
      expect(broadcaster.remote_port).to eq(6000)
    end

    it 'defaults to 127.0.0.1:5000 when no env vars' do
      broadcaster = described_class.new
      expect(broadcaster.remote_host).to eq('127.0.0.1')
      expect(broadcaster.remote_port).to eq(5000)
    end
  end

  describe '#broadcast' do
    it 'creates a UDP socket and sends message' do
      mock_socket = double('UDPSocket')
      allow(UDPSocket).to receive(:new).and_return(mock_socket)
      allow(mock_socket).to receive(:connect)
      allow(mock_socket).to receive(:send).and_return(10)

      Async do
        broadcaster.broadcast('test message')
      end

      expect(UDPSocket).to have_received(:new)
      expect(mock_socket).to have_received(:connect).with(host, port)
      expect(mock_socket).to have_received(:send).with('test message', 0)
    end

    it 'reuses socket on subsequent broadcasts' do
      mock_socket = double('UDPSocket')
      allow(UDPSocket).to receive(:new).and_return(mock_socket)
      allow(mock_socket).to receive(:connect)
      allow(mock_socket).to receive(:send).and_return(10)

      Async do
        broadcaster.broadcast('first')
        broadcaster.broadcast('second')
      end

      expect(UDPSocket).to have_received(:new).once
      expect(mock_socket).to have_received(:send).twice
    end

    it 'handles socket creation errors gracefully' do
      allow(UDPSocket).to receive(:new).and_raise(StandardError.new('Connection failed'))

      Async do
        broadcaster.broadcast('test')
      end

      # Error is logged, not raised in Async
      # Verify socket was not set
      expect(broadcaster.instance_variable_get(:@socket)).to be_nil
    end

    it 'handles send errors and clears socket' do
      mock_socket = double('UDPSocket')
      allow(UDPSocket).to receive(:new).and_return(mock_socket)
      allow(mock_socket).to receive(:connect)
      allow(mock_socket).to receive(:send).and_raise(StandardError.new('Send failed'))

      Async do
        broadcaster.broadcast('test')
      end

      expect(broadcaster.instance_variable_get(:@socket)).to be_nil
    end
  end

  describe '#close' do
    it 'closes the socket' do
      mock_socket = double('UDPSocket')
      broadcaster.instance_variable_set(:@socket, mock_socket)
      expect(mock_socket).to receive(:close)

      broadcaster.close
      expect(broadcaster.instance_variable_get(:@socket)).to be_nil
    end

    it 'does not raise error if socket is nil' do
      expect { broadcaster.close }.not_to raise_error
    end
  end
end
