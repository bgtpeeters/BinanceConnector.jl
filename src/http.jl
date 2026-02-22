# ---------------------------------------------------------------------------
# http.jl — Low-level HTTP helpers for the Binance REST API.
#
# Three entry-points used by endpoint files:
#   _public_get(client, path; params)   — unauthenticated GET
#   _signed_get(client, path; params)   — HMAC-signed GET
#   _signed_post(client, path; params)  — HMAC-signed POST
#
# All three return a parsed JSON3 object (Dict-like or Array-like).
# Non-2xx responses or Binance error payloads raise BinanceError.
# ---------------------------------------------------------------------------

"""
    _handle_response(resp) -> JSON3.Value

Parse the HTTP response body as JSON. If the status code is not 2xx, or if
the JSON payload contains a Binance error `code` field, throw `BinanceError`.
"""
function _handle_response(resp::HTTP.Response)
    body = String(resp.body)

    # Always parse JSON so we can inspect the payload for Binance error codes.
    parsed = try
        JSON3.read(body)
    catch
        # Unparseable body — fall back to a generic error with the HTTP status.
        if resp.status < 200 || resp.status >= 300
            throw(BinanceError(-1, "HTTP $(resp.status): $(body)"))
        end
        rethrow()
    end

    # Binance embeds errors as {"code": <negative int>, "msg": "..."} even
    # when the HTTP status is 400/401/429/etc.
    if parsed isa JSON3.Object && haskey(parsed, :code) && parsed[:code] < 0
        throw(BinanceError(Int(parsed[:code]), String(parsed[:msg])))
    end

    if resp.status < 200 || resp.status >= 300
        throw(BinanceError(-1, "HTTP $(resp.status): $(body)"))
    end

    return parsed
end

"""
    _public_get(client::BinanceClient, path::String; params=Dict()) -> JSON3.Value

Send an unauthenticated GET request to `client.base_url * path`.
Optional query parameters are passed via `params`.
"""
function _public_get(
    client ::BinanceClient,
    path   ::String;
    params ::AbstractDict = Dict{String,Any}(),
)
    url = client.base_url * path
    qs  = _build_query(params)
    if !isempty(qs)
        url = url * "?" * qs
    end

    headers = ["Accept" => "application/json"]
    resp    = HTTP.get(url, headers; status_exception=false)
    return _handle_response(resp)
end

"""
    _signed_get(client::BinanceClient, path::String; params=Dict()) -> JSON3.Value

Send an HMAC-SHA256–signed GET request. Adds `timestamp`, `recvWindow`, and
`signature` to the query string. Requires `client.api_key` and
`client.secret_key` to be set.
"""
function _signed_get(
    client ::BinanceClient,
    path   ::String;
    params ::AbstractDict = Dict{String,Any}(),
)
    isempty(client.api_key) && error(
        "BinanceConnector: api_key is required for signed endpoints."
    )
    signed_qs = _sign_params(client, params)
    url       = client.base_url * path * "?" * signed_qs

    headers = [
        "Accept"       => "application/json",
        "X-MBX-APIKEY" => client.api_key,
    ]
    resp = HTTP.get(url, headers; status_exception=false)
    return _handle_response(resp)
end

"""
    _signed_post(client::BinanceClient, path::String; params=Dict()) -> JSON3.Value

Send an HMAC-SHA256–signed POST request. The signed query string is sent in
the request body as `application/x-www-form-urlencoded`. Requires
`client.api_key` and `client.secret_key` to be set.
"""
function _signed_post(
    client ::BinanceClient,
    path   ::String;
    params ::AbstractDict = Dict{String,Any}(),
)
    isempty(client.api_key) && error(
        "BinanceConnector: api_key is required for signed endpoints."
    )
    signed_qs = _sign_params(client, params)
    url       = client.base_url * path

    headers = [
        "Content-Type" => "application/x-www-form-urlencoded",
        "Accept"       => "application/json",
        "X-MBX-APIKEY" => client.api_key,
    ]
    resp = HTTP.post(url, headers, signed_qs; status_exception=false)
    return _handle_response(resp)
end
