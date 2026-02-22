# ---------------------------------------------------------------------------
# endpoints/market.jl — Public market-data endpoints (no auth required).
#
#   klines(client, symbol, interval; kwargs...)  GET /api/v3/klines
#   ticker_price(client; kwargs...)              GET /api/v3/ticker/price
#   exchange_info(client; kwargs...)             GET /api/v3/exchangeInfo
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# klines
# ---------------------------------------------------------------------------

"""
    klines(client, symbol, interval; startTime, endTime, timeZone, limit) -> DataFrame

Return candlestick/kline data for `symbol` at the given `interval`.

Calls `GET /api/v3/klines` and returns a `DataFrame` with 11 typed columns,
sorted oldest → newest (most recent row last).

# Arguments
- `client::BinanceClient`
- `symbol::String`   — e.g. `"BTCUSDT"`
- `interval::String` — e.g. `"1m"`, `"1h"`, `"1d"`

# Keyword Arguments
- `startTime::Union{Int,Nothing}` — Start time in milliseconds (Unix epoch).
- `endTime::Union{Int,Nothing}`   — End time in milliseconds (Unix epoch).
- `timeZone::Union{String,Nothing}` — Timezone for open/close times (default UTC).
- `limit::Union{Int,Nothing}`     — Number of candles, max 1000, default 500.

# Columns
| Column                  | Type     |
|-------------------------|----------|
| `open_time`             | DateTime |
| `open`                  | Float64  |
| `high`                  | Float64  |
| `low`                   | Float64  |
| `close`                 | Float64  |
| `volume`                | Float64  |
| `close_time`            | DateTime |
| `quote_volume`          | Float64  |
| `num_trades`            | Int      |
| `taker_buy_base_volume` | Float64  |
| `taker_buy_quote_volume`| Float64  |

# Example

    client = BinanceClient()
    df = klines(client, "BTCUSDT", "1h"; limit=100)
"""
function klines(
    client   ::BinanceClient,
    symbol   ::String,
    interval ::String;
    startTime ::Union{Int,Nothing}    = nothing,
    endTime   ::Union{Int,Nothing}    = nothing,
    timeZone  ::Union{String,Nothing} = nothing,
    limit     ::Union{Int,Nothing}    = nothing,
)::DataFrame
    params = Dict{String,Any}(
        "symbol"   => symbol,
        "interval" => interval,
    )
    startTime !== nothing && (params["startTime"] = startTime)
    endTime   !== nothing && (params["endTime"]   = endTime)
    timeZone  !== nothing && (params["timeZone"]  = timeZone)
    limit     !== nothing && (params["limit"]     = limit)

    raw = _public_get(client, "/api/v3/klines"; params=params)

    # Each element is a 12-element array; the 12th ("Unused field") is dropped.
    # Index:  1          2      3      4      5       6
    #        open_time  open   high   low    close   volume
    # Index:  7           8              9           10                    11
    #        close_time  quote_volume  num_trades  taker_buy_base_vol  taker_buy_quote_vol

    n = length(raw)
    open_time             = Vector{DateTime}(undef, n)
    open                  = Vector{Float64}(undef,  n)
    high                  = Vector{Float64}(undef,  n)
    low                   = Vector{Float64}(undef,  n)
    close                 = Vector{Float64}(undef,  n)
    volume                = Vector{Float64}(undef,  n)
    close_time            = Vector{DateTime}(undef, n)
    quote_volume          = Vector{Float64}(undef,  n)
    num_trades            = Vector{Int}(undef,      n)
    taker_buy_base_volume = Vector{Float64}(undef,  n)
    taker_buy_quote_volume= Vector{Float64}(undef,  n)

    for (i, row) in enumerate(raw)
        open_time[i]              = unix2datetime(Int64(row[1])  / 1000)
        open[i]                   = parse(Float64, String(row[2]))
        high[i]                   = parse(Float64, String(row[3]))
        low[i]                    = parse(Float64, String(row[4]))
        close[i]                  = parse(Float64, String(row[5]))
        volume[i]                 = parse(Float64, String(row[6]))
        close_time[i]             = unix2datetime(Int64(row[7])  / 1000)
        quote_volume[i]           = parse(Float64, String(row[8]))
        num_trades[i]             = Int(row[9])
        taker_buy_base_volume[i]  = parse(Float64, String(row[10]))
        taker_buy_quote_volume[i] = parse(Float64, String(row[11]))
    end

    return DataFrame(
        open_time              = open_time,
        open                   = open,
        high                   = high,
        low                    = low,
        close                  = close,
        volume                 = volume,
        close_time             = close_time,
        quote_volume           = quote_volume,
        num_trades             = num_trades,
        taker_buy_base_volume  = taker_buy_base_volume,
        taker_buy_quote_volume = taker_buy_quote_volume,
    )
end

# ---------------------------------------------------------------------------
# ticker_price
# ---------------------------------------------------------------------------

"""
    ticker_price(client; symbol, symbols) -> Union{Dict, Vector{Dict}}

Return the latest price for one or more symbols.

Calls `GET /api/v3/ticker/price`.

- If `symbol` is given, returns a single `Dict` with keys `"symbol"` and `"price"`.
- If `symbols` is given (a vector of strings), returns a `Vector` of such dicts.
- If neither is given, returns prices for **all** symbols as a `Vector`.

# Keyword Arguments
- `symbol::Union{String,Nothing}`        — Single symbol, e.g. `"BTCUSDT"`.
- `symbols::Union{Vector{String},Nothing}` — Multiple symbols.

# Example

    client = BinanceClient()
    ticker_price(client; symbol="BTCUSDT")
    # => {"symbol" => "BTCUSDT", "price" => "30000.00"}

    ticker_price(client; symbols=["BTCUSDT", "ETHUSDT"])
"""
function ticker_price(
    client  ::BinanceClient;
    symbol  ::Union{String,Nothing}        = nothing,
    symbols ::Union{Vector{String},Nothing} = nothing,
)
    params = Dict{String,Any}()
    if symbol !== nothing
        params["symbol"] = symbol
    elseif symbols !== nothing
        # Binance expects JSON array string: ["BTCUSDT","ETHUSDT"]
        params["symbols"] = "[" * join(("\"$s\"" for s in symbols), ",") * "]"
    end

    raw = _public_get(client, "/api/v3/ticker/price"; params=params)

    # Single symbol → Object; multiple / all → Array
    if raw isa JSON3.Object
        return Dict{String,Any}(String(k) => String(v) for (k, v) in raw)
    else
        return [Dict{String,Any}(String(k) => String(v) for (k, v) in item)
                for item in raw]
    end
end

# ---------------------------------------------------------------------------
# exchange_info
# ---------------------------------------------------------------------------

"""
    exchange_info(client; symbol, symbols) -> Dict

Return exchange trading rules and symbol information.

Calls `GET /api/v3/exchangeInfo`.

- If no arguments are given, returns info for **all** symbols.
- If `symbol` is given, filters to that single symbol.
- If `symbols` is given, filters to those symbols.

# Keyword Arguments
- `symbol::Union{String,Nothing}`          — Single symbol filter.
- `symbols::Union{Vector{String},Nothing}` — Multiple symbol filter.

# Example

    client = BinanceClient()
    info = exchange_info(client; symbol="BTCUSDT")
    info["symbols"][1]["baseAsset"]   # => "BTC"
"""
function exchange_info(
    client  ::BinanceClient;
    symbol  ::Union{String,Nothing}        = nothing,
    symbols ::Union{Vector{String},Nothing} = nothing,
)::Dict
    params = Dict{String,Any}()
    if symbol !== nothing
        params["symbol"] = symbol
    elseif symbols !== nothing
        params["symbols"] = "[" * join(("\"$s\"" for s in symbols), ",") * "]"
    end

    raw = _public_get(client, "/api/v3/exchangeInfo"; params=params)
    # Convert the top-level JSON3.Object to a plain Dict for ease of use.
    return _json3_to_dict(raw)
end

# ---------------------------------------------------------------------------
# Internal helper — recursively convert JSON3 values to plain Julia types.
# ---------------------------------------------------------------------------

function _json3_to_dict(obj)
    if obj isa JSON3.Object
        return Dict{String,Any}(String(k) => _json3_to_dict(v) for (k, v) in obj)
    elseif obj isa JSON3.Array
        return [_json3_to_dict(v) for v in obj]
    elseif obj isa AbstractString
        return String(obj)
    else
        return obj  # Bool, Int, Float64, Nothing
    end
end
