# BinanceConnector.jl

[![CI](https://github.com/bgtpeeters/BinanceConnector.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/bgtpeeters/BinanceConnector.jl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A pure Julia connector to the [Binance Spot REST API](https://developers.binance.com/docs/binance-spot-api-docs/rest-api).

No PyCall. No system libraries. Just HTTP.jl.

---

## Features

- Public market-data endpoints — no credentials required
- Signed (HMAC-SHA256) wallet and trading endpoints
- `klines` returns a fully typed `DataFrame` (11 columns, oldest → newest)
- Testnet support via a single `base_url` parameter
- Clean error handling — non-2xx responses throw `BinanceError`

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/bgtpeeters/BinanceConnector.jl")
```

## Quick start

```julia
using BinanceConnector

# Public client — no credentials needed
client = BinanceClient()

# Candlestick data — returns a DataFrame, most recent row last
df = klines(client, "BTCUSDT", "1h"; limit=100)

# Latest price
price = ticker_price(client; symbol="BTCUSDT")

# Exchange rules for a symbol
info = exchange_info(client; symbol="BTCUSDT")
```

## Authenticated usage

```julia
auth = BinanceClient(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Wallet balances
assets = user_asset(auth)

# Test an order without sending it (safe!)
result = new_order_test(auth, "BTCUSDT", "BUY", "MARKET"; quoteOrderQty=10.0)

# Place a live order (use testnet first!)
order = new_order(auth, "BTCUSDT", "BUY", "MARKET"; quoteOrderQty=10.0)
```

## Testnet

```julia
testnet = BinanceClient(
    base_url   = "https://testnet.binance.vision",
    api_key    = "YOUR_TESTNET_KEY",
    secret_key = "YOUR_TESTNET_SECRET",
)
```

## API reference

### `BinanceClient`

```julia
BinanceClient(;
    base_url    = "https://api.binance.com",  # or testnet URL
    api_key     = "",
    secret_key  = "",
    recv_window = 5000,   # ms; max 60000
)
```

### `klines`

```julia
df = klines(client, symbol, interval;
    startTime = nothing,   # Unix ms
    endTime   = nothing,   # Unix ms
    timeZone  = nothing,
    limit     = nothing,   # max 1000, default 500
)
```

Returns a `DataFrame` with columns:
`open_time`, `open`, `high`, `low`, `close`, `volume`, `close_time`,
`quote_volume`, `num_trades`, `taker_buy_base_volume`, `taker_buy_quote_volume`.

### `ticker_price`

```julia
ticker_price(client; symbol=nothing, symbols=nothing)
```

Returns a `Dict` (single symbol) or `Vector{Dict}` (multiple / all symbols).

### `exchange_info`

```julia
exchange_info(client; symbol=nothing, symbols=nothing)
```

Returns a `Dict` with exchange rules and symbol information.

### `user_asset` *(signed)*

```julia
user_asset(client; asset=nothing, needBtcValuation=nothing)
```

Returns a `Vector{Dict}` of wallet asset balances.

### `new_order` *(signed)*

```julia
new_order(client, symbol, side, type;
    timeInForce=nothing, quantity=nothing, quoteOrderQty=nothing,
    price=nothing, newClientOrderId=nothing, stopPrice=nothing,
    icebergQty=nothing, newOrderRespType=nothing,
)
```

### `new_order_test` *(signed)*

Same signature as `new_order`, plus `computeCommissionRates=nothing`.
Validates the request without placing a live order.

## Error handling

All non-2xx responses and Binance error payloads throw a `BinanceError`:

```julia
try
    klines(client, "INVALID", "1h")
catch e
    e isa BinanceError && println("Code $(e.code): $(e.msg)")
end
```

## License

MIT — see [LICENSE](LICENSE).
