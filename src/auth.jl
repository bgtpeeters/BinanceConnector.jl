# ---------------------------------------------------------------------------
# auth.jl — HMAC-SHA256 signing for Binance signed endpoints.
#
# Binance signed endpoint flow:
#   1. Build query string from all parameters including timestamp.
#   2. Compute HMAC-SHA256(secret_key, query_string).
#   3. Append &signature=<hex_digest> to the query string.
# ---------------------------------------------------------------------------

"""
    _timestamp() -> Int

Return the current UTC time as a Unix timestamp in milliseconds.
Used as the `timestamp` parameter required by all signed endpoints.
"""
function _timestamp()::Int
    return round(Int, datetime2unix(now(UTC)) * 1000)
end

"""
    _hmac_sha256_hex(secret::String, message::String) -> String

Compute HMAC-SHA256 of `message` using `secret` and return the lowercase
hexadecimal digest string.
"""
function _hmac_sha256_hex(secret::String, message::String)::String
    key   = Vector{UInt8}(secret)
    msg   = Vector{UInt8}(message)
    digest = SHA.hmac_sha256(key, msg)
    return bytes2hex(digest)
end

"""
    _build_query(params::AbstractDict) -> String

Encode a dictionary of parameters into a URL query string.
Keys and values are converted to strings; nothing values are skipped.
"""
function _build_query(params::AbstractDict)::String
    parts = String[]
    for (k, v) in params
        v === nothing && continue
        push!(parts, string(k) * "=" * _urlencode(string(v)))
    end
    return join(parts, "&")
end

"""
    _urlencode(s::String) -> String

Percent-encode a string for use in a URL query string.
Leaves alphanumerics and `-_.~` unencoded per RFC 3986.
"""
function _urlencode(s::String)::String
    buf = IOBuffer()
    for c in s
        if isletter(c) || isdigit(c) || c in ('-', '_', '.', '~')
            write(buf, c)
        else
            for byte in Vector{UInt8}(string(c))
                write(buf, '%')
                write(buf, uppercase(string(byte, base=16, pad=2)))
            end
        end
    end
    return String(take!(buf))
end

"""
    _sign_params(client::BinanceClient, params::AbstractDict) -> String

Add `timestamp` and `recvWindow` to `params`, compute the HMAC-SHA256
signature, and return the fully signed query string ready to be appended
to the request URL or sent as a POST body.
"""
function _sign_params(client::BinanceClient, params::AbstractDict)::String
    isempty(client.secret_key) && error(
        "BinanceConnector: secret_key is required for signed endpoints. " *
        "Create your client with BinanceClient(api_key=..., secret_key=...)."
    )
    # Merge auth parameters
    all_params = copy(params)
    all_params["timestamp"]  = _timestamp()
    all_params["recvWindow"] = client.recv_window

    query     = _build_query(all_params)
    signature = _hmac_sha256_hex(client.secret_key, query)
    return query * "&signature=" * signature
end
