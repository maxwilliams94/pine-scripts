# Pinescript Workspace

This workspace contains TradingView Pine Script projects.

## Files

- `basicArbitrage.tps`: Example script for basic arbitrage strategies.
- `basicOracle.tps`: Example script for basic oracle integration.

## Usage

1. Open the `.tps` files in TradingView's Pine Script editor.
2. Deploy or backtest the scripts within TradingView.
3. Review and modify the scripts as needed for your trading strategy.

## Algorithm Overviews

### basicArbitrage.tps
- Implements an arbitrage trading strategy.
- Uses fixed cash amounts for buys and sells.
- Buys when price movement falls below a set negative threshold; sells when above a positive threshold.
- Respects cost basis (won’t sell below average purchase price if enabled).
- Allows customization of start/end dates, initial holdings, and display options.
- Designed for high-frequency pyramiding and backtesting.

### basicOracle.tps
- Implements an oracle-based trading strategy.
- Uses percentage of available cash for buys and percentage of current position for sells.
- Enforces minimum transaction sizes for both buys and sells.
- Buys and sells are triggered by price movement thresholds, similar to arbitrage.
- Adds a minimum profit percentage requirement for selling above cost basis.
- Customizable start date, initial holdings, and display options.
- Also supports high-frequency pyramiding and backtesting.

## Requirements

- TradingView account
- Pine Script knowledge

## License

This project is for educational purposes only.
