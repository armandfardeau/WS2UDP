# WS2XX Bridge

**[Documentation](https://armandfardeau.github.io/WS2UDP/)**

An asynchronous Ruby bridge that relays messages from a WebSocket server to any destination using pluggable strategies.

## Features

- Async WebSocket server (non-blocking I/O via `async` gem)
- **Strategy Pattern**: Pluggable broadcaster and destination strategies
- Composition over inheritance for maximum flexibility
- Environment-based configuration
- Graceful shutdown (SIGINT/SIGTERM)
- Minimal dependencies

## Requirements

- Ruby 3.0+
- Bundler

## Installation

```bash
bundle install
```

## Usage

Start the bridge with environment variables for configuration:

```bash
# Default: WebSocket on 127.0.0.1:8080, UDP target 127.0.0.1:5000
ruby bin/ws2xx

# Or with custom ports/hosts:
WS_HOST=0.0.0.0 WS_PORT=9000 UDP_HOST=192.168.1.100 UDP_PORT=6000 ruby bin/ws2xx
```

## Environment Variables

- `WS_HOST` - WebSocket server host (default: `127.0.0.1`)
- `WS_PORT` - WebSocket server port (default: `8080`)
- `UDP_HOST` - UDP target host (default: `127.0.0.1`)
- `UDP_PORT` - UDP target port (default: `5000`)

## Manual Testing

### Terminal 1: Start the bridge
```bash
WS_PORT=8080 UDP_PORT=5000 ruby bin/ws2xx
```

### Terminal 2: Listen for UDP messages
```bash
nc -l -u 127.0.0.1 5000
```

### Terminal 3: Send a WebSocket message
```bash
ruby -e "
  require 'websocket-client-simple'
  ws = WebSocket::Client::Simple.connect 'ws://127.0.0.1:8080'
  ws.send 'Hello from WebSocket!'
  ws.close
"
```

You should see the message appear in Terminal 2.

## Architecture

### Strategy Pattern Structure

```
BroadcasterStrategy (interface)
  ├── Broadcasters::UDP
  └── Broadcasters::HTTP (future)

RouteStrategy (interface)
  ├── Route::UDP
  ├── Route::WebSocket
  ├── Route::HTTP (future)
  └── Route::Composite (chains multiple destinations)

Builder
  └── Composes destination strategies at runtime
```

### File Structure

```
lib/ws2xx/
├── ws2xx.rb                          # Main entry point & builder
├── websocket_server.rb               # WebSocket server (uses destination strategies)
├── strategies.rb                     # Strategies loader
└── strategies/
    ├── broadcaster_strategy.rb       # BroadcasterStrategy base interface
    ├── route_strategy.rb             # Destination strategy base interface
    ├── builder.rb                    # Strategy builder/composer
    ├── broadcasters/
    │   └── udp.rb                   # UDP broadcaster strategy
    └── route/
        ├── udp.rb                   # UDP destination strategy
        ├── websocket.rb             # WebSocket destination strategy
        └── composite.rb             # Composite destination strategy
```

## Extending WS2XX

### Adding a new broadcaster strategy

```ruby
module WS2XX
  module Strategies
    module Broadcasters
      class Kafka < BroadcasterStrategy
        def initialize(brokers)
          @brokers = brokers
        end

        def broadcast(message)
          # Send via Kafka producer
        end

        def close
          # Cleanup
        end
      end
    end
  end
end
```

### Adding a new destination strategy

```ruby
module WS2XX
  module Strategies
    module Route
      class Kafka < RouteStrategy
        def initialize(broadcaster)
          @broadcaster = broadcaster
        end

        def route(message, source_type)
          puts "[DESTINATION] #{source_type.capitalize} → Kafka"
          @broadcaster.broadcast(message)
        end

        def close
          @broadcaster.close if @broadcaster.respond_to?(:close)
        end
      end
    end
  end
end
```

### Using custom strategies

```ruby
# In main entry point (ws2xx.rb)
builder = Strategies::Builder.new
builder.register_route(:kafka, Strategies::Route::Kafka.new(kafka_broadcaster))

destinations = builder.build_routes(
  kafka_enabled: true
)

ws_server.set_destination_strategy(destinations)
```

## Benefits of Strategy Pattern

| Benefit | How it helps |
|---------|------------|
| **Composition** | Mix and match broadcaster/destination strategies at runtime |
| **Extensibility** | Add new strategies without modifying existing code |
| **Testability** | Mock/stub strategies for isolated unit tests |
| **Flexibility** | Chain multiple destinations (e.g., UDP + Kafka + HTTP) |
| **Decoupling** | WebSocket server doesn't know about destinations |

## Known Limitations

- UDP is connectionless and best-effort; messages may be lost
- No message ordering guarantees for high-throughput scenarios
- WebSocket client connections are handled sequentially in the async loop
- No built-in authentication or TLS termination

## Future Enhancements

- Bidirectional relay (UDP → WebSocket with Route::WebSocket)
- HTTP broadcaster/destination strategies
- Kafka producer/consumer strategies
- Message filtering and transformation pipelines
- Metrics and logging improvements
- TLS/WSS support
- Connection pooling for strategies