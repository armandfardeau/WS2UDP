# frozen_string_literal: true

require 'spec_helper'
require 'ws2xx/broadcasters/tcp'

describe WS2XX::Broadcasters::TCP, :aggregate_failures do
  subject(:broadcaster) { described_class.new(host, port) }

  let(:host) { '127.0.0.1' }
  let(:port) { 6000 }

  describe '#initialize' do
    it 'sets remote_host and remote_port from arguments' do
      expect(broadcaster.remote_host).to eq(host)
      expect(broadcaster.remote_port).to eq(port)
    end

    it 'uses environment variables as defaults' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('TCP_HOST').and_return('192.168.1.1')
      allow(ENV).to receive(:[]).with('TCP_PORT').and_return('7000')

      broadcaster = described_class.new
      expect(broadcaster.remote_host).to eq('192.168.1.1')
      expect(broadcaster.remote_port).to eq(7000)
    end

    it 'defaults to 127.0.0.1:5000 when no env vars' do
      broadcaster = described_class.new
      expect(broadcaster.remote_host).to eq('127.0.0.1')
      expect(broadcaster.remote_port).to eq(5000)
    end
  end

  describe '#broadcast' do
    it 'creates a TCP endpoint and sends message' do
      mock_endpoint = double('IO::Endpoint::HostEndpoint')
      mock_socket = double('Socket')
      allow(IO::Endpoint).to receive(:tcp).with(host, port).and_return(mock_endpoint)
      allow(mock_endpoint).to receive(:connect).and_yield(mock_socket)
      allow(mock_socket).to receive(:write).and_return(10)

      Async do
        broadcaster.broadcast('test message')
      end

      expect(IO::Endpoint).to have_received(:tcp).with(host, port)
      expect(mock_endpoint).to have_received(:connect)
      expect(mock_socket).to have_received(:write).with('test message')
    end

    it 'reuses endpoint on subsequent broadcasts' do
      mock_endpoint = double('IO::Endpoint::HostEndpoint')
      mock_socket = double('Socket')
      allow(IO::Endpoint).to receive(:tcp).with(host, port).and_return(mock_endpoint)
      allow(mock_endpoint).to receive(:connect).and_yield(mock_socket)
      allow(mock_socket).to receive(:write).and_return(10)

      Async do
        broadcaster.broadcast('first')
        broadcaster.broadcast('second')
      end

      expect(IO::Endpoint).to have_received(:tcp).once
      expect(mock_endpoint).to have_received(:connect).twice
      expect(mock_socket).to have_received(:write).twice
    end

    it 'handles endpoint creation errors gracefully' do
      allow(IO::Endpoint).to receive(:tcp).and_raise(StandardError.new('Connection failed'))

      Async do
        broadcaster.broadcast('test')
      end

      expect(broadcaster.instance_variable_get(:@endpoint)).to be_nil
    end

    it 'handles send errors and clears endpoint' do
      mock_endpoint = double('IO::Endpoint::HostEndpoint')
      allow(IO::Endpoint).to receive(:tcp).with(host, port).and_return(mock_endpoint)
      allow(mock_endpoint).to receive(:connect).and_raise(StandardError.new('Write failed'))
      allow(mock_endpoint).to receive(:respond_to?).with(:close).and_return(true)
      allow(mock_endpoint).to receive(:close)

      Async do
        broadcaster.broadcast('test')
      end

      expect(broadcaster.instance_variable_get(:@endpoint)).to be_nil
    end
  end

  describe '#close' do
    it 'closes the endpoint when it supports close' do
      mock_endpoint = double('IO::Endpoint::HostEndpoint')
      broadcaster.instance_variable_set(:@endpoint, mock_endpoint)
      allow(mock_endpoint).to receive(:respond_to?).with(:close).and_return(true)
      expect(mock_endpoint).to receive(:close)

      broadcaster.close
      expect(broadcaster.instance_variable_get(:@endpoint)).to be_nil
    end

    it 'does not raise error if endpoint is nil' do
      expect { broadcaster.close }.not_to raise_error
    end
  end
end
