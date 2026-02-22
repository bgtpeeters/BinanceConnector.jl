# Contributing to BinanceConnector.jl

Thank you for your interest in contributing!

## Reporting issues

Please open a GitHub issue and include:
- Julia version (`julia --version`)
- A minimal reproducible example
- The full error message / stack trace

## Submitting changes

1. Fork the repository and create a feature branch.
2. Make your changes; add or update tests in `test/runtests.jl`.
3. Run the test suite locally:
   ```
   julia --project -e "using Pkg; Pkg.test()"
   ```
4. Open a pull request against `main` with a clear description of the change.

## Code style

- Follow the conventions already present in the codebase.
- Document all exported functions with a docstring.
- Keep lines to 100 characters where practical.

## Signed-endpoint tests

Tests for `user_asset`, `new_order`, and `new_order_test` are skipped when
`BINANCE_API_KEY` and `BINANCE_SECRET_KEY` are not set in the environment.
To run them locally, export those variables before calling `Pkg.test()`.
