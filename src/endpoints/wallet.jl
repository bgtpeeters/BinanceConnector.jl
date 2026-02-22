# ---------------------------------------------------------------------------
# endpoints/wallet.jl — Signed wallet and trading endpoints.
#
#   user_asset(client; kwargs...)                     POST /sapi/v3/asset/getUserAsset
#   new_order(client, symbol, side, type; kwargs...)  POST /api/v3/order
#   new_order_test(client, symbol, side, type; ...)   POST /api/v3/order/test
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# user_asset
# ---------------------------------------------------------------------------

"""
    user_asset(client; asset, needBtcValuation) -> Vector{Dict}

Return user wallet asset information.

Calls `POST /sapi/v3/asset/getUserAsset` (signed).

# Keyword Arguments
- `asset::Union{String,Nothing}` — Filter to a specific asset, e.g. `"BTC"`.
  If omitted, all non-zero balances are returned.
- `needBtcValuation::Union{Bool,Nothing}` — If `true`, include the BTC
  valuation of each asset.

# Returns
A `Vector{Dict}` where each dict contains fields such as:
`"asset"`, `"free"`, `"locked"`, `"freeze"`, `"withdrawing"`, `"ipoable"`,
`"btcValuation"`.

# Example

    auth = BinanceClient(api_key="KEY", secret_key="SECRET")
    assets = user_asset(auth)
    assets = user_asset(auth; asset="BTC", needBtcValuation=true)
"""
function user_asset(
    client            ::BinanceClient;
    asset             ::Union{String,Nothing} = nothing,
    needBtcValuation  ::Union{Bool,Nothing}   = nothing,
)::Vector{Dict}
    params = Dict{String,Any}()
    asset            !== nothing && (params["asset"]            = asset)
    needBtcValuation !== nothing && (params["needBtcValuation"] = needBtcValuation)

    raw = _signed_post(client, "/sapi/v3/asset/getUserAsset"; params=params)

    return [_json3_to_dict(item) for item in raw]
end

# ---------------------------------------------------------------------------
# new_order
# ---------------------------------------------------------------------------

"""
    new_order(client, symbol, side, type; kwargs...) -> Dict

Place a new order on the exchange.

Calls `POST /api/v3/order` (signed).

# Arguments
- `client::BinanceClient`
- `symbol::String` — Trading pair, e.g. `"BTCUSDT"`.
- `side::String`   — `"BUY"` or `"SELL"`.
- `type::String`   — Order type: `"LIMIT"`, `"MARKET"`, `"STOP_LOSS"`,
  `"STOP_LOSS_LIMIT"`, `"TAKE_PROFIT"`, `"TAKE_PROFIT_LIMIT"`,
  `"LIMIT_MAKER"`.

# Keyword Arguments
Common optional parameters (see Binance docs for the full list):
- `timeInForce::Union{String,Nothing}` — `"GTC"`, `"IOC"`, `"FOK"`. Required for `LIMIT`.
- `quantity::Union{Real,Nothing}`      — Order quantity.
- `quoteOrderQty::Union{Real,Nothing}` — Quote asset quantity (for `MARKET` orders).
- `price::Union{Real,Nothing}`         — Limit price. Required for `LIMIT`.
- `newClientOrderId::Union{String,Nothing}` — Custom order ID.
- `stopPrice::Union{Real,Nothing}`     — Stop price for stop orders.
- `icebergQty::Union{Real,Nothing}`    — Iceberg quantity.
- `newOrderRespType::Union{String,Nothing}` — Response format: `"ACK"`, `"RESULT"`, `"FULL"`.

# Returns
A `Dict` with the order response. Fields depend on `newOrderRespType`.

# Example

    auth   = BinanceClient(api_key="KEY", secret_key="SECRET")
    # Test on testnet first!
    result = new_order(auth, "BTCUSDT", "BUY", "MARKET"; quantity=0.001)
"""
function new_order(
    client ::BinanceClient,
    symbol ::String,
    side   ::String,
    type   ::String;
    timeInForce        ::Union{String,Nothing} = nothing,
    quantity           ::Union{Real,Nothing}   = nothing,
    quoteOrderQty      ::Union{Real,Nothing}   = nothing,
    price              ::Union{Real,Nothing}   = nothing,
    newClientOrderId   ::Union{String,Nothing} = nothing,
    stopPrice          ::Union{Real,Nothing}   = nothing,
    icebergQty         ::Union{Real,Nothing}   = nothing,
    newOrderRespType   ::Union{String,Nothing} = nothing,
)::Dict
    params = Dict{String,Any}(
        "symbol" => symbol,
        "side"   => side,
        "type"   => type,
    )
    timeInForce      !== nothing && (params["timeInForce"]      = timeInForce)
    quantity         !== nothing && (params["quantity"]         = quantity)
    quoteOrderQty    !== nothing && (params["quoteOrderQty"]    = quoteOrderQty)
    price            !== nothing && (params["price"]            = price)
    newClientOrderId !== nothing && (params["newClientOrderId"] = newClientOrderId)
    stopPrice        !== nothing && (params["stopPrice"]        = stopPrice)
    icebergQty       !== nothing && (params["icebergQty"]       = icebergQty)
    newOrderRespType !== nothing && (params["newOrderRespType"] = newOrderRespType)

    raw = _signed_post(client, "/api/v3/order"; params=params)
    return _json3_to_dict(raw)
end

# ---------------------------------------------------------------------------
# new_order_test
# ---------------------------------------------------------------------------

"""
    new_order_test(client, symbol, side, type; kwargs...) -> Dict

Test a new order without actually placing it on the exchange.

Calls `POST /api/v3/order/test` (signed). Validates the request and returns
an empty dict `{}` on success (or a dict with commission info if
`computeCommissionRates=true`).

Accepts the same keyword arguments as [`new_order`](@ref), plus:
- `computeCommissionRates::Union{Bool,Nothing}` — If `true`, return the
  commission rates that would be charged.

# Example

    auth   = BinanceClient(api_key="KEY", secret_key="SECRET")
    result = new_order_test(auth, "BTCUSDT", "BUY", "MARKET"; quantity=0.001)
    # => Dict() if the order parameters are valid
"""
function new_order_test(
    client ::BinanceClient,
    symbol ::String,
    side   ::String,
    type   ::String;
    timeInForce            ::Union{String,Nothing} = nothing,
    quantity               ::Union{Real,Nothing}   = nothing,
    quoteOrderQty          ::Union{Real,Nothing}   = nothing,
    price                  ::Union{Real,Nothing}   = nothing,
    newClientOrderId       ::Union{String,Nothing} = nothing,
    stopPrice              ::Union{Real,Nothing}   = nothing,
    icebergQty             ::Union{Real,Nothing}   = nothing,
    newOrderRespType       ::Union{String,Nothing} = nothing,
    computeCommissionRates ::Union{Bool,Nothing}   = nothing,
)::Dict
    params = Dict{String,Any}(
        "symbol" => symbol,
        "side"   => side,
        "type"   => type,
    )
    timeInForce            !== nothing && (params["timeInForce"]            = timeInForce)
    quantity               !== nothing && (params["quantity"]               = quantity)
    quoteOrderQty          !== nothing && (params["quoteOrderQty"]          = quoteOrderQty)
    price                  !== nothing && (params["price"]                  = price)
    newClientOrderId       !== nothing && (params["newClientOrderId"]       = newClientOrderId)
    stopPrice              !== nothing && (params["stopPrice"]              = stopPrice)
    icebergQty             !== nothing && (params["icebergQty"]             = icebergQty)
    newOrderRespType       !== nothing && (params["newOrderRespType"]       = newOrderRespType)
    computeCommissionRates !== nothing && (params["computeCommissionRates"] = computeCommissionRates)

    raw = _signed_post(client, "/api/v3/order/test"; params=params)
    return _json3_to_dict(raw)
end
