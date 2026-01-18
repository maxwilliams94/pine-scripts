// This Pine Script® code is subject to the terms of the Mozilla Public License 2.0 at https://mozilla.org/MPL/2.0/
// © Arbitrage Strategy

//@version=6
strategy("ContainedExcitement's Arbitrage", overlay=true, fill_orders_on_standard_ohlc=true, calc_on_every_tick=true, process_orders_on_close=true, pyramiding=1000, initial_capital=10000)

// ============================================================================
// INPUT PARAMETERS
// ============================================================================

// Fixed Amount Mode
fixedBuyCash = input.float(100, "Fixed Buy Cash", minval=0.01, tooltip="Cash amount to spend on each buy", group="Trading")
fixedSellCash = input.float(50, "Fixed Sell Cash", minval=0.01, tooltip="Cash amount target for each sell", group="Trading")

// Initial Equity & Cost Basis
initialQuantity = input.float(0, "Initial Quantity Held", minval=0, tooltip="Existing quantity of asset already held", group="Trading")
initialAvgCostBasis = input.float(0, "Initial Avg Cost Basis", minval=0, tooltip="Average cost basis of existing holdings", group="Trading")

// Price Movement Thresholds
enableBuy = input.bool(true, "Enable Buy", tooltip="If checked, buy orders will be placed", group="Trading", inline="buyToggle")
buyThreshold = input.float(-2.5, "Buy on % Move", tooltip="Trigger buy when bar price movement (open-close) is below this % (e.g., -2.5 means -2.5%)", group="Trading", inline="buyThreshold")

enableSell = input.bool(true, "Enable Sell", tooltip="If checked, sell orders will be placed", group="Trading", inline="sellToggle")
sellThreshold = input.float(3.5, "Sell on % Move", tooltip="Trigger sell when bar price movement (open-close) is above this % (e.g., 3.5 means +3.5%)", group="Trading", inline="sellThreshold")

// Cost Basis Control
respectCostBasis = input.bool(true, "Respect Cost Basis", tooltip="If enabled, will not sell below average cost basis", group="Cost Basis")
showCostBasis = input.bool(true, "Show Cost Basis", group="Cost Basis", tooltip="If enabled, displays the average cost basis on the chart")
showPositionSize = input.bool(true, "Show Position Size", group="Cost Basis", tooltip="If enabled, displays the current number of coins/shares owned on the chart")

// Start Date Controls
startYear = input.int(2025, "Year", minval=2000, maxval=2100, group="Start Date", inline="startDate")
startMonth = input.int(1, "Month", minval=1, maxval=12, group="Start Date", inline="startDate")
startDay = input.int(1, "Day", minval=1, maxval=31, group="Start Date", inline="startDate")
startHour = input.int(0, "Hour", minval=0, maxval=23, group="Start Date", inline="startDate")

// End Date Controls
endYear = input.int(2030, "Year", minval=2000, maxval=2100, group="End Date", inline="endDate")
endMonth = input.int(12, "Month", minval=1, maxval=12, group="End Date", inline="endDate")
endDay = input.int(31, "Day", minval=1, maxval=31, group="End Date", inline="endDate")
endHour = input.int(23, "Hour", minval=0, maxval=23, group="End Date", inline="endDate")

// Create timestamps from inputs
startDate = timestamp(startYear, startMonth, startDay, startHour, 0, 0)
endDate = timestamp(endYear, endMonth, endDay, endHour, 0, 0)

// Backtest Options
limitToAvailableCapital = input.bool(true, "Limit to Available Capital", group="Backtest", tooltip="If enabled, only use available cash without leverage")
exitOnLastBar = input.bool(true, "Exit Full Position on Last Historical Bar", group="Backtest", tooltip="If enabled, close all positions on the last historical bar")


// ============================================================================
// VARIABLES FOR COST BASIS TRACKING
// ============================================================================

var float totalCostBasis = na
var float totalQuantityHeld = na
var float averageCostBasis = na

// Track realized profit from closed trades
var float totalRealizedProfit = 0.0
var int lastClosedTradesCount = 0

// Initialize cost basis on first bar
if barstate.isfirst
    if initialQuantity > 0 and initialAvgCostBasis > 0
        totalQuantityHeld := initialQuantity
        totalCostBasis := initialQuantity * initialAvgCostBasis
        averageCostBasis := initialAvgCostBasis
    else
        totalCostBasis := 0.0
        totalQuantityHeld := 0.0
        averageCostBasis := 0.0

// ============================================================================
// FUNCTIONS
// ============================================================================

// Check if we're within the date range
f_isDateValid() =>
    time >= startDate and time <= endDate

// ============================================================================
// ENTRY LOGIC
// ============================================================================

// Detect price movement down (open > close)
priceMovedDown = open > close

// Detect price movement up (close > open)
priceMovedUp = close > open

// Calculate percentage move for current bar: (close - open) / open * 100
barPriceMovePct = ((close - open) / open) * 100

// Check if bar price movement meets thresholds
buySignal = barPriceMovePct <= buyThreshold
sellSignal = barPriceMovePct >= sellThreshold

// Calculate quantities for fixed mode
buyQuantity = fixedBuyCash / close
sellQuantity = fixedSellCash / close
buyCashAmount = fixedBuyCash
sellCashAmount = fixedSellCash

// Apply capital limit if enabled
if limitToAvailableCapital
    maxBuyQty = strategy.equity / close
    buyQuantity := math.min(buyQuantity, maxBuyQty)

// Check if we're in trading window
inTradingWindow = f_isDateValid()

// Check if we're on the last historical bar
isLastBar = barstate.islast

// Update realized profit from closed trades
if strategy.closedtrades > lastClosedTradesCount
    for i = lastClosedTradesCount to strategy.closedtrades - 1
        totalRealizedProfit += strategy.closedtrades.profit(i)
    lastClosedTradesCount := strategy.closedtrades

// BUY CONDITION: Price movement meets buy threshold and we're in the trading window
if enableBuy and buySignal and inTradingWindow
    actualBuyCash = fixedBuyCash
    actualBuyQuantity = actualBuyCash / close
    
    if actualBuyQuantity > 0
        buyComment = "BUY $" + str.tostring(actualBuyCash, "#,##0.00")
        strategy.order("Buy Order", strategy.long, qty=actualBuyQuantity, comment=buyComment)
        // Update cost basis for buy
        totalCostBasis := totalCostBasis + (actualBuyQuantity * close)
        totalQuantityHeld := totalQuantityHeld + actualBuyQuantity
        if totalQuantityHeld > 0
            averageCostBasis := totalCostBasis / totalQuantityHeld

// SELL CONDITION: Price movement meets sell threshold, we're in the trading window, and we have a position
if enableSell and sellSignal and inTradingWindow and strategy.position_size > 0
    // Check cost basis constraint - don't sell below average cost basis
    canSell = not respectCostBasis or close >= averageCostBasis
    
    if canSell
        actualSellCash = fixedSellCash
        actualSellQty = math.min(actualSellCash / close, strategy.position_size)
        
        if actualSellQty > 0
            sellComment = "SELL $" + str.tostring(actualSellQty * close, "#,##0.00")
            strategy.order("Sell Order", strategy.short, qty=actualSellQty, comment=sellComment)
            // Update cost basis for sell
            if totalQuantityHeld > 0
                costRemoved = (actualSellQty / totalQuantityHeld) * totalCostBasis
                totalCostBasis := math.max(0, totalCostBasis - costRemoved)
                totalQuantityHeld := math.max(0, totalQuantityHeld - actualSellQty)
                if totalQuantityHeld > 0
                    averageCostBasis := totalCostBasis / totalQuantityHeld
                else
                    averageCostBasis := 0.0

// EXIT ON LAST BAR: Close all positions if enabled
if exitOnLastBar and isLastBar and strategy.position_size > 0
    strategy.exit("Exit Last Bar", limit=close, qty_percent=100)
    totalCostBasis := 0.0
    totalQuantityHeld := 0.0
    averageCostBasis := 0.0

// ============================================================================
// DISPLAY INFORMATION
// ============================================================================

// Plot cost basis line
plot(showCostBasis and averageCostBasis > 0 ? averageCostBasis : na, "Average Cost Basis", color=color.blue, linewidth=2, style=plot.style_linebr)

// Plot position size line
plot(showPositionSize ? strategy.position_size : na, "Position Size", color=color.green, linewidth=2, style=plot.style_line)

// Calculate tracking values for data window display
currentCryptoDollars = strategy.position_size
currentCryptoValue = strategy.position_size * close
currentCash = strategy.equity - currentCryptoValue

// Plot current cash line
plot(currentCash, "Current Cash", color=color.orange, linewidth=2, style=plot.style_line)
portfolioValue = strategy.equity
nextBuyValue = fixedBuyCash
nextSellValue = fixedSellCash

// Plot values to data window
plot(currentCryptoDollars, "Current Crypto (#)", display=display.data_window)
plot(currentCryptoValue, "Current Crypto Value ($)", display=display.data_window)
plot(currentCash, "Current Cash ($)", display=display.data_window)
plot(portfolioValue, "Portfolio Value ($)", display=display.data_window)
plot(totalRealizedProfit, "Realized Profit ($)", display=display.data_window)
plot(averageCostBasis, "Cost Basis ($)", display=display.data_window)
plot(close, "Current Price ($)", display=display.data_window)
plot(nextBuyValue, "Next Buy Value ($)", display=display.data_window)
plot(nextSellValue, "Next Sell Value ($)", display=display.data_window)
