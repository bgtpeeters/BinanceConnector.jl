# Changelog

All notable changes to BinanceConnector.jl are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `BinanceClient` now accepts a `cache_ttl` keyword argument (default 3600 s).
  `exchange_info` results are cached per symbol for that duration, avoiding
  redundant API calls when placing multiple orders. Set `cache_ttl=0.0` to disable.
- `new_order` and `new_order_test` now automatically round `quantity`, `price`,
  `stopPrice`, and `icebergQty` to the symbol's `LOT_SIZE` step and `PRICE_FILTER`
  tick precision before sending, eliminating "too much precision" rejections.
- `new_order` checks minimum notional value for `MARKET`+`quantity` orders against
  the symbol's `MIN_NOTIONAL` filter using the live price, and throws `BinanceError`
  with a clear message if the order value is too small.

### Fixed
- `_build_query` now formats `Real`-typed parameters with up to 8 decimal places
  in fixed-point notation, preventing floating-point artifacts such as
  `"0.0014700000000000002"` from reaching the API.

## [0.1.0] — Initial release

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
