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
    _format_number_for_url(v::Real) -> String

Format a numeric value for use in a Binance query string.
Integers are converted directly; floating-point values are rounded to 8
decimal places and formatted in fixed-point notation (never scientific notation),
with trailing zeros stripped.

This prevents floating-point artifacts such as `"0.0014700000000000002"` that
cause Binance to reject requests with a precision error.

Implementation uses integer arithmetic to avoid any additional floating-point
representation issues and to guarantee fixed-point output.
"""
function _format_number_for_url(v::Real)::String
    v isa Integer && return string(v)
    # Round to 8 decimal places, then express as integer * 10^-8.
    # This avoids both floating-point artifacts and scientific notation.
    int_rep = round(Int64, round(v, digits=8) * 1e8)
    int_rep == 0 && return "0"
    neg = int_rep < 0
    int_rep = abs(int_rep)
    # Pad to at least 9 digits so splitting off 8 decimal digits always works.
    s = lpad(string(int_rep), 9, '0')
    result = s[1:end-8] * "." * s[end-7:end]
    result = rstrip(result, '0')
    endswith(result, '.') && (result = result[1:end-1])
    neg && (result = "-" * result)
    return result
end

"""
    _build_query(params::AbstractDict) -> String

Encode a dictionary of parameters into a URL query string.
Keys and values are converted to strings; nothing values are skipped.
Numeric (Real) values are formatted via `_format_number_for_url` to avoid
floating-point artifacts in the query string.
"""
function _build_query(params::AbstractDict)::String
    parts = String[]
    for (k, v) in params
        v === nothing && continue
        v_str = v isa Real ? _format_number_for_url(v) : string(v)
        push!(parts, string(k) * "=" * _urlencode(v_str))
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
