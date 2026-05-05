# ---------------------------------------------------------------------------
# BinanceClient — holds connection configuration for every API call.
# ---------------------------------------------------------------------------

"""
    BinanceClient(; base_url, api_key, secret_key, recv_window, cache_ttl)

Configuration object passed to every API function.

# Keyword Arguments
- `base_url::String`    — Base URL of the Binance REST API.
                          Default: `"https://api.binance.com"`.
                          Use `"https://testnet.binance.vision"` for testnet.
- `api_key::String`     — Binance API key. Required for signed endpoints.
                          Default: `""` (public endpoints only).
- `secret_key::String`  — Binance secret key used for HMAC-SHA256 signing.
                          Required for signed endpoints. Default: `""`.
- `recv_window::Int`    — Milliseconds the server accepts a signed request
                          after its timestamp. Max 60000. Default: `5000`.
- `cache_ttl::Float64`  — Seconds to cache `exchange_info` responses per symbol.
                          Default: `3600.0` (1 hour). Set to `0.0` to disable.

# Examples

    # Public client — market data only, no credentials needed
    client = BinanceClient()

    # Authenticated client — required for wallet and trading endpoints
    auth = BinanceClient(api_key = "abc123", secret_key = "xyz789")

    # Testnet client
    testnet = BinanceClient(
        base_url   = "https://testnet.binance.vision",
        api_key    = "testnet_key",
        secret_key = "testnet_secret",
    )
"""
mutable struct BinanceClient
    const base_url    ::String
    const api_key     ::String
    const secret_key  ::String
    const recv_window ::Int
    const cache_ttl   ::Float64
    _exchange_info_cache ::Dict{String, Tuple{Dict{String,Any}, Float64}}
end

function BinanceClient(;
    base_url    ::String  = "https://api.binance.com",
    api_key     ::String  = "",
    secret_key  ::String  = "",
    recv_window ::Int     = 5000,
    cache_ttl   ::Float64 = 3600.0,
)
    return BinanceClient(
        base_url, api_key, secret_key, recv_window, cache_ttl,
        Dict{String, Tuple{Dict{String,Any}, Float64}}(),
    )
end

# ---------------------------------------------------------------------------
# BinanceError — thrown when the API returns a non-2xx response or an
# error payload in the JSON body.
# ---------------------------------------------------------------------------

"""
    BinanceError(code, msg)

Exception thrown when the Binance API returns an error.

Fields:
- `code::Int`   — Binance error code (e.g. -1121 for invalid symbol).
- `msg::String` — Human-readable error message from the API.
"""
struct BinanceError <: Exception
    code ::Int
    msg  ::String
end

function Base.showerror(io::IO, e::BinanceError)
    print(io, "BinanceError($(e.code)): $(e.msg)")
end
