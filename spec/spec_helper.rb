# frozen_string_literal: true

require 'bundler/setup'
require 'rspec'
require 'async/rspec'
require 'json'

# Disable Async's debug console logger to suppress task warnings
begin
  require 'console'
  Console.logger.level = :fatal if Console.respond_to?(:logger)
rescue LoadError
  # Console not available, continue
end

# Mock Console logger to suppress output during tests
module Console
  def self.logger
    @logger ||= SilentLogger.new
  end
end

class SilentLogger
  def info(message); end

  def warn(message)
    handle_async_warning(message)
  end

  def error(message); end
  def debug(message); end

  private

  def handle_async_warning(message)
    # Silently ignore async task warnings
  end
end

# Add lib directory to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

# Require the main modules
require 'ws2xx'
