# frozen_string_literal: true

require 'spec_helper'
require 'ws2xx/broadcasters/composite'

describe WS2XX::Broadcasters::Composite, :aggregate_failures do
  subject(:composite) { described_class.new }

  describe '#initialize' do
    it 'accepts optional array of broadcasters' do
      broadcaster1 = instance_double(WS2XX::Broadcasters::Base)
      broadcaster2 = instance_double(WS2XX::Broadcasters::Base)

      composite = described_class.new([broadcaster1, broadcaster2])
      expect(composite.instance_variable_get(:@broadcasters)).to eq([broadcaster1, broadcaster2])
    end

    it 'defaults to empty array' do
      expect(composite.instance_variable_get(:@broadcasters)).to eq([])
    end
  end

  describe '#add_broadcaster' do
    it 'adds a broadcaster to the list' do
      broadcaster = instance_double(WS2XX::Broadcasters::Base)

      result = composite.add_broadcaster(broadcaster)

      expect(composite.instance_variable_get(:@broadcasters)).to include(broadcaster)
      expect(result).to be(composite) # returns self for chaining
    end

    it 'supports method chaining' do
      broadcaster1 = instance_double(WS2XX::Broadcasters::Base)
      broadcaster2 = instance_double(WS2XX::Broadcasters::Base)

      result = composite
               .add_broadcaster(broadcaster1)
               .add_broadcaster(broadcaster2)

      expect(result).to be(composite)
      broadcasters = composite.instance_variable_get(:@broadcasters)
      expect(broadcasters).to eq([broadcaster1, broadcaster2])
    end
  end

  describe '#broadcast' do
    it 'broadcasts to all child broadcasters' do
      broadcaster1 = instance_double(WS2XX::Broadcasters::Base)
      broadcaster2 = instance_double(WS2XX::Broadcasters::Base)
      allow(broadcaster1).to receive(:broadcast)
      allow(broadcaster2).to receive(:broadcast)

      composite.add_broadcaster(broadcaster1).add_broadcaster(broadcaster2)

      Async do
        composite.broadcast('test message')
      end

      expect(broadcaster1).to have_received(:broadcast).with('test message')
      expect(broadcaster2).to have_received(:broadcast).with('test message')
    end

    it 'broadcasts to empty list without error' do
      expect do
        Async do
          composite.broadcast('test')
        end
      end.not_to raise_error
    end

    it 'broadcasts to all broadcasters even if one errors' do
      broadcaster1 = instance_double(WS2XX::Broadcasters::Base)
      broadcaster2 = instance_double(WS2XX::Broadcasters::Base)
      broadcaster3 = instance_double(WS2XX::Broadcasters::Base)
      allow(broadcaster1).to receive(:broadcast)
      allow(broadcaster2).to receive(:broadcast).and_raise(StandardError, 'Error in 2')
      allow(broadcaster3).to receive(:broadcast)

      composite.add_broadcaster(broadcaster1).add_broadcaster(broadcaster2).add_broadcaster(broadcaster3)

      Async do
        composite.broadcast('test')
      end

      expect(broadcaster1).to have_received(:broadcast)
      expect(broadcaster2).to have_received(:broadcast)
      expect(broadcaster3).to have_received(:broadcast)
    end
  end

  describe '#close' do
    it 'closes all broadcasters' do
      broadcaster1 = instance_double(WS2XX::Broadcasters::Base)
      broadcaster2 = instance_double(WS2XX::Broadcasters::Base)
      allow(broadcaster1).to receive(:close)
      allow(broadcaster2).to receive(:close)

      composite.add_broadcaster(broadcaster1).add_broadcaster(broadcaster2)
      composite.close

      expect(broadcaster1).to have_received(:close)
      expect(broadcaster2).to have_received(:close)
    end

    it 'only closes broadcasters that respond to close' do
      broadcaster1 = instance_double(WS2XX::Broadcasters::Base)
      broadcaster2 = instance_double(String) # doesn't respond to close
      allow(broadcaster1).to receive(:close)

      composite.add_broadcaster(broadcaster1).add_broadcaster(broadcaster2)

      expect { composite.close }.not_to raise_error
      expect(broadcaster1).to have_received(:close)
    end

    it 'does not error with no broadcasters' do
      expect { composite.close }.not_to raise_error
    end
  end
end
