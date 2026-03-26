# frozen_string_literal: true

require 'spec_helper'
require 'ws2xx/broadcasters/base'

describe WS2XX::Broadcasters::Base do
  describe '#broadcast' do
    it 'raises NotImplementedError' do
      broadcaster = WS2XX::Broadcasters::Base.new
      expect { broadcaster.broadcast('message') }.to raise_error(NotImplementedError)
    end
  end

  describe '#close' do
    it 'does not raise an error' do
      broadcaster = WS2XX::Broadcasters::Base.new
      expect { broadcaster.close }.not_to raise_error
    end
  end
end
