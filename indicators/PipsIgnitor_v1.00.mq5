//+------------------------------------------------------------------+
//|                                            PipsIgnitor_v1.00.mq5 |
//|                                 Copyright 2025, Maxime Bourdouxhe|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Maxime Bourdouxhe."
#property link      "https://www.mql5.com"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Utils.mqh>
#include <TradingFunctions.mqh>
#include <ErrorDescription.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>

CPositionInfo m_position;
COrderInfo m_order;
CTrade m_trade;
CSymbolInfo m_symbol;
CAccountInfo m_account;
CMoneyFixedMargin *m_money;

enum RiskLevels {
    VeryLow,
    Low,
    Medium,
    High,
    VeryHigh
};

enum Pairs {
    GRAPH_FIXED,
    EURUSD_GBPUSD,
    EURUSD_USDCAD,
    GBPUSD_USDCAD,
    EURUSD_GBPUSD_USDCAD
};


input string        General_Settings = " ---- ---- ---- ----- General ----- ---- ---- ---- ";
input ushort        Slippage = 3;      			            // Slippage Maximum
input ushort        SpreadMax = 2;                          // Spread Maximum
input ulong         MagicNumber = 123456789;                // Magic Number
input double        BaseLot = 0.0;                          // Lot (Set 0 To Use Risk Level)

input string        Risk_Settings = " ---- ---- ---- ---- -- Risk -- ---- ---- ---- ---- ";
input RiskLevels    RiskLevel = Low;                        // Risk Level

input string        Pairs_Settings = " ---- ---- ---- ---- -- Pairs -- ---- ---- ---- ---- ";
input Pairs         PairsToTrade = GRAPH_FIXED;             // Pairs To Trade

input string        Candles_Settings = " ---- ---- ---- ---- - Candles - ---- ---- ---- ---- ";
input int           CandleMinDelta = 25;                    // Candle Minimum Delta 

input string        ATR_Settings = " ---- ---- ---- ---- --- ATR --- ---- ---- ---- ---- ";
input uchar         ATRPeriod = 14;                         // ATR Period
input int           ATRMaxStoploss = 20;                    // ATR Maximum StopLoss In Pips
input int           ATRMinStoploss = 5;                     // ATR Minimum StopLoss In Pips

input string        TrailingStop_Settings = " ---- ---- ---- -- Trailing Stop -- ---- ---- ---- ";
input ushort        TrailingPips = 5;                       // Trailing Stop In Pips
input ushort        TrailingStep = 5;                       // Trailing Step In Pips

input string        Time_Settings = " ---- ---- ---- ---- -- Time -- ---- ---- ---- ---- ";
input bool          HourFilter = false;			            // Enable Hour Filtering
input uchar         StartHour = 1;				            // Start Hour
input uchar         EndHour = 23;				            // End Hour				

input string        Grid_Settings = " ---- ---- ---- ---- -- Grid -- ---- ---- ---- ---- ";
input float         GridProfitFactor = 1;                   // Grid Profit Factor
input bool          GridMartingal = true;                   // Grid Enable Martingal
input uchar         GridMaxPositions = 30;                  // Grid Limit Positions (Set 0 to disable)
input int           GridCloseMaxDrawDown = 0;               // Grid Drawdown Maximum In % To Close All (Set 0 to disable)

input string        Informations_Settings = " ---- ---- ---- -- Informations -- ---- ---- ---- ";
input bool          InformationsDisplay = true;             // Display Trade Informations
//input LogLevels     Level = CRITICAL;                   // Logs Level


double ATRMultiplier = 2;
bool ADXFiltering = true;
int ADXPeriod = 14;

int ATRMultiplierADX = 5;
int MinADXThreshold = 30;
double ATRBaseLine = 0.001;
double BaseADXThreshold = 30;

// Depends of user inputs
double ExtTrailingStop = 0.0;
double ExtTrailingStep = 0.0;              

// Misc
double m_adjusted_point = 0;
long m_last_deal_IN = 0;

// Indicator handles
int atrHandle, adxHandle, maFastHandle;
IndicatorRef atr, adx, maFast;

// Price delta
double minEntryDelta = 0;
double currentDelta = 0;

// Grid
double gridLevel = 0, gridTraillingPrice = 0, gridBalance = 0;
ENUM_POSITION_TYPE gridPosType = 0;
//int gridNumberPos = 0;
bool gridAllowed = true, isGriding = false;
datetime gridStart = 0, gridEnd = 0;

// Money Management
double accountBalance = 0, calculedLot = 0, minExitProfit = 0;
double riskMultiplier = 1, lastMultiplier = 0, nextLot = 0;

string pairToTrade[];
int numberOfPair = 0;

// Indicators
double atrMinGridThreshold = 0.0004;
double atrMaxGridThreshold = 1000000000;
int maFastPeriod = 12;

bool isInitNeeded = true;

int minBarsRequired = 10;
int referenceBarsIndex = 0;



bool pendingOrdersSet = false;
bool gridLevelSet = false;

input double TrailOffset    = 2; //5;  // Distance (in points) from current price to SL
input double TrailStep      = 5; //10; // Minimum favorable move to trail SL (in points)
input int GridMinExitProfit = 10;

// Globals
double trailStartPrice = 0;
double currentStopLoss = 0;
bool trailingActive = false;

// Deals Management
int numberPositions = 0;
int numberOrders = 0;

struct LimitOrder {
    string symbol;
    int bars;
    ulong ticketLong;
    ulong ticketShort;
};

struct SymbolInfo {
    string symbol;
    double spread;
};

LimitOrder limitOrders[];
SymbolInfo symbolInfos;


//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit() {
    PrintLog(__FUNCTION__, "Expert initialization ...", INFO);
    
    TesterHideIndicators(true);
    StyleChart();
    
	if(StartHour >= EndHour) {
		Alert(__FUNCTION__, "Traiding is not possible: the parameter \"Start hour\" (", StartHour, ") >= \"End hour\" (", EndHour, ") !");
		return(INIT_PARAMETERS_INCORRECT);
	}

	if(StartHour > 24) {
		Alert(__FUNCTION__, "Traiding is not possible: the parameter \"Start hour\" (", StartHour, ") > 24 !");
		return(INIT_PARAMETERS_INCORRECT);
	}

	if(EndHour > 24) {
		Alert(__FUNCTION__, "Traiding is not possible: the parameter \"End hour\" (", EndHour, ") > 24 !");
		return(INIT_PARAMETERS_INCORRECT);
	}

    if(PairsToTrade == GRAPH_FIXED) {
        ArrayResize(pairToTrade, 1);
        pairToTrade[0] = Symbol();
    } else if(PairsToTrade == EURUSD_GBPUSD) {
        ArrayResize(pairToTrade, 2);
        pairToTrade[0] = "EURUSD";
        pairToTrade[1] = "GBPUSD";
    } else if(PairsToTrade == EURUSD_USDCAD) {
        ArrayResize(pairToTrade, 2);
        pairToTrade[0] = "EURUSD";
        pairToTrade[1] = "USDCAD";
    } else if(PairsToTrade == GBPUSD_USDCAD) {
        ArrayResize(pairToTrade, 2);
        pairToTrade[0] = "GBPUSD";
        pairToTrade[1] = "USDCAD";
    } else {
        ArrayResize(pairToTrade, 3);
        pairToTrade[0] = "EURUSD";
        pairToTrade[1] = "GBPUSD";
        pairToTrade[2] = "USDCAD";
    }

    numberOfPair = ArraySize(pairToTrade);
    ArrayResize(limitOrders, numberOfPair);
    //ArrayResize(symbolInfos, numberOfPair);
	
	if(RiskLevel == VeryLow) riskMultiplier = 0.5;
	if(RiskLevel == Low) riskMultiplier = 1;
	if(RiskLevel == Medium) riskMultiplier = 1.5;
    if(RiskLevel == High) riskMultiplier = 2;
    if(RiskLevel == VeryHigh) riskMultiplier = 2.5;

    InitByPair(pairToTrade[0]);

    // Set m_trade
    m_trade.LogLevel(LOG_LEVEL_NO);
	m_trade.SetExpertMagicNumber(MagicNumber);
	m_trade.SetMarginMode();
	m_trade.SetDeviationInPoints(Slippage);
	
    referenceBarsIndex = Bars(m_symbol.Name(), PERIOD_M1);    
    
    PrintLog(__FUNCTION__, "Expert initialization done.", INFO);
	return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {   
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick() {
    PrintLog(__FUNCTION__, " +---------- Execution ----------+", DEBUG);
    
    if(!IsEnoughBars(_Symbol, minBarsRequired)) return;
    
    PrintLog(__FUNCTION__, " Checking bot position ...", DEBUG);
    
    numberPositions = CountBotPositions();
    numberOrders = CountBotOrders();

    if(numberPositions == 0) {
        isInitNeeded = true;
        trailingActive = false;
        isGriding = false;
        gridLevel = 0;
        symbolInfos.spread = NULL;
        symbolInfos.symbol = NULL;
        
        
        if(numberOrders == 0) {
            PrintLog(__FUNCTION__, " Calculating lots & minimum profit ...", DEBUG);
            
            calculedLot = BaseLot;
            if(BaseLot == 0) {
                accountBalance = m_account.Balance();
                calculedLot = CalculateLot(accountBalance, riskMultiplier);
            }

            nextLot = calculedLot;
            minExitProfit = GridMinExitProfit * calculedLot * GridProfitFactor;
            
            if(minExitProfit < 0.5) minExitProfit = 0.5;
        } 
        
        // +--- Orders management ---+
        for(int i = 0; i < numberOfPair; i++) {
            if(InitByPair(pairToTrade[i]) != INIT_SUCCEEDED) return; 

            string symb = m_symbol.Name();
            int currentBars = Bars(symb, PERIOD_M1);

            
            if(limitOrders[i].symbol == symb) {
                if(limitOrders[i].bars > 0) {
                    if(currentBars - limitOrders[i].bars >= 4) {
                        //if(
                            DeleteLimitOrders(limitOrders[i].ticketLong);
                            DeleteLimitOrders(limitOrders[i].ticketShort);
                            limitOrders[i].ticketLong = 0;
                            limitOrders[i].ticketShort = 0;
                            limitOrders[i].symbol = NULL;
                            limitOrders[i].bars = 0;
                        //}
                    } else {
                        break;    
                    }
                }
            }
      
            if(symbolInfos.spread <= SpreadMax) {
                if(limitOrders[i].symbol == NULL && limitOrders[i].bars == 0) {
                    double buyPrice = m_symbol.Ask() - minEntryDelta;
                    double sellPrice = m_symbol.Bid() + minEntryDelta;
                    
                    limitOrders[i].ticketLong = SetLimitOrder(ORDER_TYPE_BUY_LIMIT, buyPrice, calculedLot, 0, 0, symb);
                    limitOrders[i].ticketShort = SetLimitOrder(ORDER_TYPE_SELL_LIMIT, sellPrice, calculedLot, 0, 0, symb);
                   
                    limitOrders[i].symbol = symb;
                    limitOrders[i].bars = currentBars;
                }
            } else {
                PrintLog(__FUNCTION__, " Spread is too high on " + symb + " (" + string(symbolInfos.spread) + " pts)", DEBUG);
            }
        }
    } else {
        PrintLog(__FUNCTION__, " New position detected.", DEBUG);
        
        if(isInitNeeded) {
            if(m_position.SelectByIndex(numberPositions-1)) {
                symbolInfos.symbol = m_position.Symbol();
                InitByPair(symbolInfos.symbol);
            } else {
                PrintLog(__FUNCTION__, " Select by index failed !", ERROR);
            }
            
            DeleteAllLimitOrders();
            ResetLimitOrdersVars();
            isInitNeeded = false;
        }
                TrailingStop();
    GridExit();
    GridEntry();
         }
    
    // Management of current position(s)

}

//+------------------------------------------------------------------+
//| On Trade Handler                                                 |
//+------------------------------------------------------------------+
void OnTrade() {
    /*numberPositions = CountBotPositions();
    
    if(numberPositions == 0) {
        PrintLog(__FUNCTION__, " No position.", DEBUG);
        PrintLog(__FUNCTION__, " Reseting variables ...", DEBUG);
        

    }*/
}

//+------------------------------------------------------------------+
//| Entry Grid                                                       |
//+------------------------------------------------------------------+
void GridEntry(void) {   
    if(numberPositions >= GridMaxPositions) return;
    if(!RefreshRates()) return;
    //if(!ATR(atrMinGridThreshold, atrMaxGridThreshold)) return;
    //if(GetSpread() > SpreadMax) return;
    

    // Select the latest position
    if(m_position.SelectByIndex(numberPositions-1)) {

        if(m_position.Symbol() == m_symbol.Name() && m_position.Magic() == MagicNumber) {

            double multiplier = 0;
            
            if(numberPositions == 1) {
                gridBalance = m_account.Balance();
            } else {
                if(GridMartingal) {
                    //if(lastMultiplier == 0) lastMultiplier = gridNumberPos;
                    
                    // Increase the lot only if ADX ok
                    // Else we use the same lot as the previous position
                    if(!ADX()) {    
                        multiplier = 1;
                    } else {
                        multiplier = numberPositions - 1;
                        //lastMultiplier = gridNumberPos;
                    }
                }
            }
            
            
            nextLot = calculedLot;
            if(multiplier > 0) nextLot *= multiplier;
            
            if(m_position.PositionType() == POSITION_TYPE_BUY) {
                if(gridLevel == 0) {
                    gridLevel = m_position.PriceOpen() - GetDynamicStopLoss();
                }
                
                if(m_symbol.Ask() < gridLevel && MAFast(1) == 1) {
        
                    if(OpenBuy(0, 0)) {
                        isGriding = true;
                        //if(!isGriding) {
                            //gridStart = TimeCurrent();
                            //isGriding = true;
                        //}
			            //gridPosType = POSITION_TYPE_BUY;
			            //gridNumberPos++;
                        gridLevel = m_symbol.Ask() - GetDynamicStopLoss() * 1;
                    }
                }
            } else if(m_position.PositionType() == POSITION_TYPE_SELL) {
                if(gridLevel == 0) {
                    gridLevel = m_position.PriceOpen() + GetDynamicStopLoss();
                }
                if(m_symbol.Bid() > gridLevel && MAFast(1) == -1) {
  
                    if(OpenSell(0, 0)) {
                        isGriding = true;
                        //if(!isGriding) {
                            //gridStart = TimeCurrent();
                            //isGriding = true;
                        //}
			            //gridPosType = POSITION_TYPE_SELL;
			            //gridNumberPos++;
                        gridLevel = m_symbol.Bid() + GetDynamicStopLoss() * 1;
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Exit Grid                                                        |
//+------------------------------------------------------------------+
void GridExit(void) {
    if(!isGriding) return;
    
    double profit = GetBalanceEquityDelta();
	if(profit > minExitProfit && m_account.Equity() >= m_account.Balance()) {
		GridTrailingStop();
		return;
   	}

   	if(numberPositions >= 6) {
       	if(m_account.Equity() >= m_account.Balance()) {
       	    CloseAllPositions();
       	}
   	}
}


//+------------------------------------------------------------------+
//| Get ATR Based StopLoss                                           |
//+------------------------------------------------------------------+
double GetDynamicStopLoss(void) { 
    double atrValues[];  
	if(!SafeCopyBuffer(atr, 0, 0, 1, atrValues)) {
        return(0);
    }
   
    double value = NormalizeDouble(atrValues[0] * ATRMultiplier, 5);
    double pipsSL = NormalizeDouble(value / m_adjusted_point, 0);  
    double sl = value;
 
    if(pipsSL > ATRMaxStoploss) {
        sl = ATRMaxStoploss * m_adjusted_point;
    } else if(pipsSL < ATRMinStoploss) {
        sl = ATRMinStoploss * m_adjusted_point;
    }
    
    sl = NormalizeDouble(sl, 5);
    PrintLog(__FUNCTION__, "Dynamic stoploss: " + string(sl), DEBUG);
    
    return(sl);
}

//+------------------------------------------------------------------+
//| Sum All Possitions Profits                                       |
//+------------------------------------------------------------------+
double GetBalanceEquityDelta(void) {
	double total = 0;

	for(int i = numberPositions-1; i >= 0; i--) {
		if(m_position.SelectByIndex(i)) {
		    if(m_position.Symbol() == m_symbol.Name() && m_position.Magic() == MagicNumber) {
			    total += m_position.Profit();
			}
		}
	}
	PrintLog(__FUNCTION__, " Total positions profit: " + string(total), DEBUG);
	return(total);
}

//+------------------------------------------------------------------+
//| Reset All Limit Orders Global Variables                          |
//+------------------------------------------------------------------+
void ResetLimitOrdersVars() {
    for(int i = 0; i < numberOfPair; i++) {
        limitOrders[i].symbol = NULL;
        limitOrders[i].bars = NULL;
    }
    symbolInfos.spread = NULL;
    symbolInfos.symbol = NULL;
}









//+------------------------------------------------------------------+
//| Moving Average                                                   |
//+------------------------------------------------------------------+
int MAFast(int numberBars) {
    // Ensure numberBars to be at least 1
    numberBars = MathMax(1, numberBars);
    
    double values[];
    if(!SafeCopyBuffer(maFast, 0, 0, numberBars, values)) {
        return(0);
    }
    
    // Handle the case when we check only one value
    if(numberBars == 1) {
        if(m_symbol.Ask() > values[0]) {
            return(1);
        } else if(m_symbol.Bid() < values[0]) {
            return(-1);
        }
        return(0);
    }
    
    int directionCounter = 0;
    for(int i=0; i < numberBars-1; i++) {
        if(values[i] > values[i+1]) {
            directionCounter++;
        } else if(values[i] < values[i+1]) {
            directionCounter--;
        }
    }
    
    if(MathAbs(directionCounter) == numberBars-1) {
    	return directionCounter > 0 ? 1 : -1;
    }
	return(0);
}

//+------------------------------------------------------------------+
//| Average True Range                                               |
//+------------------------------------------------------------------+
bool ATR(double min, double max) {
    double values[];
	if(!SafeCopyBuffer(atr, 0, 0, 1, values)) {
        return(false);
    }
    
    if(values[0] >= min && values[0] <= max) return(true);
    return(false);
}

//+------------------------------------------------------------------+
//| Average Directional Movement Index                               |
//+------------------------------------------------------------------+
bool ADX(void) {
    if(!ADXFiltering) return(true);
    
    double values[];
	if(!SafeCopyBuffer(adx, 0, 0, 1, values)) {
        return(false);
    }
    
    double dynamicThreshold = GetDynamicAdxThreshold();    
    return values[0] < dynamicThreshold ? true : false;
}

//+------------------------------------------------------------------+
//| Dynamic ADX Threshold                                            |
//+------------------------------------------------------------------+
double GetDynamicAdxThreshold(void) {    
	double atrValues[];
	if(!SafeCopyBuffer(atr, 0, 0, 1, atrValues)) {
        return(0);
    }
    
    double adjustement = 0;
    if(atrValues[0] > ATRBaseLine) {
        adjustement = ATRMultiplierADX * ((atrValues[0] - ATRBaseLine) / ATRBaseLine);  
    }
    
    double dynamicThreshold = BaseADXThreshold - adjustement;
    
    if(dynamicThreshold < MinADXThreshold) {
        dynamicThreshold = MinADXThreshold;
    }
    
    PrintLog(__FUNCTION__, "Getting dynamic ADX threshold: " +  string(dynamicThreshold), DEBUG);
    return(dynamicThreshold);
}

//+------------------------------------------------------------------+
//| Refresh Rates                                                    |
//+------------------------------------------------------------------+
bool RefreshRates(void) {
    m_symbol.Refresh();
    
    if(!m_symbol.IsSynchronized()) {
		PrintLog(__FUNCTION__, " Symbol is not synchronized with the server !", ERROR);
		return(false);
    }
    
	if(!m_symbol.RefreshRates()) {
	    int err = GetLastError();
		PrintLog(__FUNCTION__, " Error: " + ErrorDescription(err), ERROR);
		return(false);
	}
    m_symbol.Refresh();
	// Protection against the return value of "zero"
	if(m_symbol.Ask() == 0 || m_symbol.Bid() == 0) {
	    Print("Ask: ", m_symbol.Ask());
	    Print("Bid: ", m_symbol.Bid());
	    PrintLog(__FUNCTION__, " Returned 0 as value for Bid or Ask !", ERROR);
	    return(false);
	}
	return(true);
}

//+------------------------------------------------------------------+
//| Pair Initialization                                              |
//+------------------------------------------------------------------+
int InitByPair(string pair) {
    PrintLog(__FUNCTION__, " Initializing symbol: " + pair, DEBUG);
    
	if(!m_symbol.Name(pair)) { 
	    PrintLog(__FUNCTION__, " Init failed for symbol: " + pair, ERROR);
		return(INIT_FAILED);
	}
    
    if(!m_symbol.Refresh()) {
        PrintLog(__FUNCTION__, " Init refresh failed for symbol: " + pair, ERROR);
        return(INIT_FAILED);
    }
    
    for(int i = 0; i < numberOfPair; i++) {
        if(pair == pairToTrade[i]) {
            symbolInfos.symbol = m_symbol.Name();
            symbolInfos.spread = GetSpread();
            break;
        }
        
    }    
    
    atrHandle = iATR(pair, PERIOD_CURRENT, ATRPeriod);
    adxHandle = iADX(pair, PERIOD_CURRENT, ADXPeriod);
    maFastHandle = iMA(pair, PERIOD_CURRENT, maFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    atr = IndicatorRef(atrHandle, "ATR");
    adx = IndicatorRef(adxHandle, "ADX");
    maFast = IndicatorRef(maFastHandle, "Fast Moving Average");

	RefreshRates();
	
	// Tuning for 3 or 5 digits
	int digits_adjust = 1;
	if(m_symbol.Digits() == 3 || m_symbol.Digits() == 5) {
		digits_adjust = 10;
	}
	
	m_adjusted_point = m_symbol.Point() * digits_adjust;
	
	// Adjust variables with adjusted point
	ExtTrailingStop = TrailingPips * m_adjusted_point;
	ExtTrailingStep = TrailingStep * m_adjusted_point;
	minEntryDelta = CandleMinDelta * m_adjusted_point;
	
	m_trade.SetTypeFillingBySymbol(pair);
	
	PrintLog(__FUNCTION__, " Initialization successfull for symbol " + pair, DEBUG);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Get Current Spread                                               |
//+------------------------------------------------------------------+
double GetSpread(void) {
    if(!RefreshRates()) return(0);
    
    double spread = NormalizeDouble((m_symbol.Ask() - m_symbol.Bid()) / m_adjusted_point, m_symbol.Digits());
    
    PrintLog(__FUNCTION__, " Spread: " + string(spread), DEBUG);
	return(spread);
}