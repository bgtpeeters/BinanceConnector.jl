# Changelog

All notable changes to BinanceConnector.jl are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `BinanceClient` struct with keyword constructor and testnet support.
- `BinanceError` exception type with Binance error code and message.
- `klines` — returns a typed `DataFrame` with 11 columns (oldest → newest).
- `ticker_price` — single symbol, multiple symbols, or all symbols.
- `exchange_info` — exchange rules filtered by symbol(s).
- `user_asset` — signed POST to retrieve wallet balances.
- `new_order` — signed POST to place live orders.
- `new_order_test` — signed POST to validate orders without execution.
- HMAC-SHA256 signing via SHA.jl — no external system dependencies.
- GitHub Actions CI on Julia 1.10 and latest stable.
