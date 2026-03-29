---
layout: default
title: WS2XX Bridge
description: An asynchronous Ruby bridge that relays WebSocket messages to UDP/TCP endpoints.
---

# WS2XX Bridge

An asynchronous Ruby bridge that subscribes to a WebSocket server and forwards messages to one or more UDP or TCP endpoints. Designed for real-time data pipelines such as AIS maritime vessel tracking.

## Features

- **Async I/O** — Non-blocking WebSocket client powered by the [`async`](https://github.com/socketry/async) gem
- **Pluggable destinations** — Route messages to UDP, TCP, or multiple endpoints simultaneously via a composite broadcaster
- **AIS message filtering** — Filter by message type (`PositionReport`, `ShipStaticData`, `SafetyBroadcastMessage`) and ship MMSI
- **Bounding box filtering** — Restrict messages to a geographic region
- **NMEA conversion** — Converts JSON WebSocket payloads to NMEA sentences before forwarding
- **Auto-reconnect** — Optional indefinite reconnection on WebSocket errors
- **Graceful shutdown** — Handles `SIGINT`/`SIGTERM` cleanly

## Requirements

- Ruby 3.0+
- Bundler

## Installation

```bash
git clone https://github.com/your-org/ws2xx.git
cd ws2xx
bundle install
```

## Quick Start

```bash
# Forward WebSocket messages to a local UDP port
ws2xx --ws-url ws://myserver.example.com/stream \
      --destination udp://127.0.0.1:5000

# Forward to both UDP and TCP simultaneously
ws2xx --ws-url ws://myserver.example.com/stream \
      --destination udp://127.0.0.1:5000 \
      --destination tcp://127.0.0.1:6000
```

## CLI Reference

```
Usage: ws2xx [options]

WebSocket Configuration:
    --ws-url HOST                WebSocket server URL
    --ws-api-key KEY             WebSocket API key
    --ws-bounding-boxes BOXES    Geographic bounding boxes
                                 Format: minLat,minLon,maxLat,maxLon
                                 Separate multiple boxes with '|'

Destination Configuration (can be used multiple times):
    --destination TYPE://HOST:PORT
                                 Add a destination
                                 Examples: udp://127.0.0.1:5000
                                           tcp://192.168.1.10:6000

Other options:
    --message-types TYPES        Comma-separated message types to forward
                                 Default: PositionReport,ShipStaticData,SafetyBroadcastMessage
    --mmsis MMSIS                Comma-separated ship MMSIs to filter
    --reconnect-on-error         Reconnect indefinitely on WebSocket errors

Common options:
    -h, --help                   Show this message
    --version                    Show version
```

## Examples

### Filter by message type

```bash
ws2xx --ws-url ws://feed.example.com/ais \
      --destination udp://127.0.0.1:5000 \
      --message-types PositionReport
```

### Filter by MMSI

```bash
ws2xx --ws-url ws://feed.example.com/ais \
      --destination udp://127.0.0.1:5000 \
      --mmsis 123456789,987654321
```

### Restrict to a geographic bounding box

```bash
ws2xx --ws-url ws://feed.example.com/ais \
      --destination udp://127.0.0.1:5000 \
      --ws-bounding-boxes 51.0,-1.5,52.0,1.5
```

Multiple boxes (pipe-separated):

```bash
--ws-bounding-boxes "51.0,-1.5,52.0,1.5|48.0,2.0,49.0,3.5"
```

### Auto-reconnect on error

```bash
ws2xx --ws-url ws://feed.example.com/ais \
      --destination udp://127.0.0.1:5000 \
      --reconnect-on-error
```

### Authenticate with an API key

```bash
ws2xx --ws-url ws://feed.example.com/ais \
      --ws-api-key YOUR_API_KEY \
      --destination udp://127.0.0.1:5000
```

## Manual Testing

**Terminal 1 — start the bridge:**

```bash
ws2xx --ws-url ws://127.0.0.1:8080 --destination udp://127.0.0.1:5000
```

**Terminal 2 — listen for UDP packets:**

```bash
nc -l -u 127.0.0.1 5000
```

**Terminal 3 — send a test WebSocket message:**

```ruby
require 'websocket-client-simple'
ws = WebSocket::Client::Simple.connect 'ws://127.0.0.1:8080'
ws.send '{"Message":{"PositionReport":{"UserID":123456789}}}'
ws.close
```

The message should appear in Terminal 2 as an NMEA sentence.

## Architecture

```
WebSocketClient
  └── receives JSON messages from upstream WebSocket server
  └── parses and converts to NMEA via Message
  └── passes to Broadcaster

Broadcaster (Strategy Pattern)
  ├── Broadcasters::UDP    — single UDP destination
  ├── Broadcasters::TCP    — single TCP destination
  └── Broadcasters::Composite — fans out to multiple destinations
        ├── Broadcasters::UDP
        └── Broadcasters::TCP

CLI → Bridge → WebSocketClient + Broadcaster
```

The `Broadcasters::Builder` factory inspects the `--destination` flags at startup and composes the appropriate strategy: a single broadcaster for one destination, or a `Composite` for many.

## Message Flow

1. WS2XX connects to the upstream WebSocket URL
2. Incoming JSON frames are parsed by `Message`
3. The JSON payload is converted to an NMEA sentence via `ais_to_nmea`
4. The NMEA string is forwarded to all configured destinations

## License

See [LICENSE](../LICENSE) for details.
