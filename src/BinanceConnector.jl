"""
    BinanceConnector

A pure Julia connector to the Binance Spot REST API.

Provides native Julia bindings via HTTP.jl — no PyCall, no system libraries.
Supports both public (unauthenticated) and signed (HMAC-SHA256) endpoints.

# Quick start

    using BinanceConnector

    # Public client — no credentials needed
    client = BinanceClient()

    # Kline/candlestick data — returns a DataFrame, most recent row last
    df = klines(client, "BTCUSDT", "1h"; limit=100)

    # Latest price
    price = ticker_price(client; symbol="BTCUSDT")

    # Exchange information
    info = exchange_info(client; symbol="BTCUSDT")

    # Authenticated client
    auth = BinanceClient(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

    # User wallet assets
    assets = user_asset(auth)

    # Place a market order (live — use testnet first!)
    order = new_order(auth, "BTCUSDT", "BUY", "MARKET"; quantity=0.001)

    # Test an order without sending it to the matching engine
    result = new_order_test(auth, "BTCUSDT", "BUY", "MARKET"; quantity=0.001)

# Testnet

    testnet = BinanceClient(
        base_url   = "https://testnet.binance.vision",
        api_key    = "YOUR_TESTNET_KEY",
        secret_key = "YOUR_TESTNET_SECRET",
    )
"""
module BinanceConnector

using HTTP
using JSON3
using SHA
using Dates
using DataFrames

include("client.jl")
include("auth.jl")
include("http.jl")
include("endpoints/market.jl")
include("endpoints/wallet.jl")

export BinanceClient
export BinanceError
export klines
export ticker_price
export exchange_info
export user_asset
export new_order
export new_order_test

end # module BinanceConnector
