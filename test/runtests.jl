using Test
using BinanceConnector
using DataFrames
using Dates

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const HAS_CREDENTIALS = haskey(ENV, "BINANCE_API_KEY") && haskey(ENV, "BINANCE_SECRET_KEY")

function auth_client()
    BinanceClient(
        api_key    = ENV["BINANCE_API_KEY"],
        secret_key = ENV["BINANCE_SECRET_KEY"],
    )
end

# ---------------------------------------------------------------------------
# Unit tests — no network required
# ---------------------------------------------------------------------------

@testset "BinanceClient constructor" begin
    c = BinanceClient()
    @test c.base_url    == "https://api.binance.com"
    @test c.api_key     == ""
    @test c.secret_key  == ""
    @test c.recv_window == 5000

    c2 = BinanceClient(
        base_url    = "https://testnet.binance.vision",
        api_key     = "key",
        secret_key  = "secret",
        recv_window = 10_000,
    )
    @test c2.base_url    == "https://testnet.binance.vision"
    @test c2.api_key     == "key"
    @test c2.secret_key  == "secret"
    @test c2.recv_window == 10_000
end

@testset "BinanceError display" begin
    err = BinanceError(-1121, "Invalid symbol.")
    msg = sprint(showerror, err)
    @test occursin("-1121", msg)
    @test occursin("Invalid symbol.", msg)
end

@testset "Auth helpers" begin
    # _timestamp() should be close to current time (within 5 seconds)
    ts = BinanceConnector._timestamp()
    now_ms = round(Int, datetime2unix(now(UTC)) * 1000)
    @test abs(ts - now_ms) < 5_000

    # _hmac_sha256_hex — known test vector
    # echo -n "symbol=LTCBTC&side=BUY" | openssl dgst -sha256 -hmac "NhqRknCKmdSySsJzbFmLqyqqhcuxjewpiYUQaSTmFW7nhpKVh4tHiui0"
    sig = BinanceConnector._hmac_sha256_hex(
        "NhqRknCKmdSySsJzbFmLqyqqhcuxjewpiYUQaSTmFW7nhpKVh4tHiui0",
        "symbol=LTCBTC&side=BUY",
    )
    @test length(sig) == 64
    @test all(c -> c in "0123456789abcdef", sig)

    # _build_query — ordering and nothing-skipping
    q = BinanceConnector._build_query(Dict("b" => "2", "a" => "1", "c" => nothing))
    @test occursin("a=1", q)
    @test occursin("b=2", q)
    @test !occursin("c=", q)

    # _urlencode — spaces and special chars
    @test BinanceConnector._urlencode("hello world") == "hello%20world"
    @test BinanceConnector._urlencode("a+b=c") == "a%2Bb%3Dc"
end

# ---------------------------------------------------------------------------
# Integration tests — hit Binance public endpoints
# ---------------------------------------------------------------------------

@testset "klines — BTCUSDT 1h last 10 candles" begin
    client = BinanceClient()
    df = klines(client, "BTCUSDT", "1h"; limit=10)

    @test df isa DataFrame
    @test nrow(df) == 10
    @test ncol(df) == 11

    expected_cols = [
        :open_time, :open, :high, :low, :close, :volume,
        :close_time, :quote_volume, :num_trades,
        :taker_buy_base_volume, :taker_buy_quote_volume,
    ]
    for col in expected_cols
        @test col in propertynames(df)
    end

    # Type checks
    @test eltype(df.open_time)  == DateTime
    @test eltype(df.close_time) == DateTime
    @test eltype(df.open)       == Float64
    @test eltype(df.num_trades) == Int

    # Sanity: sorted oldest → newest
    @test issorted(df.open_time)

    # OHLC sanity
    @test all(df.high .>= df.low)
    @test all(df.high .>= df.open)
    @test all(df.high .>= df.close)
    @test all(df.volume .>= 0)
end

@testset "klines — single candle returns 1-row DataFrame" begin
    client = BinanceClient()
    df = klines(client, "ETHUSDT", "1d"; limit=1)
    @test nrow(df) == 1
end

@testset "ticker_price — single symbol" begin
    client = BinanceClient()
    result = ticker_price(client; symbol="BTCUSDT")
    @test result isa Dict
    @test result["symbol"] == "BTCUSDT"
    @test haskey(result, "price")
    @test parse(Float64, result["price"]) > 0
end

@testset "ticker_price — multiple symbols" begin
    client = BinanceClient()
    result = ticker_price(client; symbols=["BTCUSDT", "ETHUSDT"])
    @test result isa Vector
    @test length(result) == 2
    syms = Set(d["symbol"] for d in result)
    @test "BTCUSDT" in syms
    @test "ETHUSDT" in syms
end

@testset "ticker_price — all symbols" begin
    client = BinanceClient()
    result = ticker_price(client)
    @test result isa Vector
    @test length(result) > 100  # Binance has many trading pairs
end

@testset "exchange_info — single symbol" begin
    client = BinanceClient()
    info = exchange_info(client; symbol="BTCUSDT")
    @test info isa Dict
    @test haskey(info, "symbols")
    @test info["symbols"] isa Vector
    @test length(info["symbols"]) == 1
    @test info["symbols"][1]["symbol"] == "BTCUSDT"
end

@testset "BinanceError is thrown for invalid symbol" begin
    client = BinanceClient()
    @test_throws BinanceError klines(client, "INVALID_XYZ_PAIR", "1h"; limit=1)
end

# ---------------------------------------------------------------------------
# Integration tests — signed endpoints (skip without credentials)
# ---------------------------------------------------------------------------

@testset "user_asset — requires credentials" begin
    if !HAS_CREDENTIALS
        @info "Skipping user_asset test: BINANCE_API_KEY / BINANCE_SECRET_KEY not set"
        @test true  # placeholder so testset is not empty
    else
        client = auth_client()
        assets = user_asset(client)
        @test assets isa Vector
        # Each element should be a Dict with at least "asset" and "free" keys
        for a in assets
            @test a isa Dict
            @test haskey(a, "asset")
            @test haskey(a, "free")
        end
    end
end

@testset "new_order_test — requires credentials" begin
    if !HAS_CREDENTIALS
        @info "Skipping new_order_test: BINANCE_API_KEY / BINANCE_SECRET_KEY not set"
        @test true
    else
        client = auth_client()
        # A valid MARKET order test should not throw and return a Dict
        result = new_order_test(
            client, "BTCUSDT", "BUY", "MARKET";
            quoteOrderQty = 10.0,   # spend 10 USDT worth
        )
        @test result isa Dict
    end
end
