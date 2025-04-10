//+------------------------------------------------------------------+
//|                                               ZigZag Analyzer.mq5|
//|                                   Copyright 2025, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

// Input parameters
input ENUM_TIMEFRAMES InpTimeFrame    = PERIOD_CURRENT; // Timeframe to analyze
input int             ZZ_Depth         = 12;  // ZigZag depth
input int             ZZ_Deviation     = 5;   // ZigZag deviation
input int             ZZ_Backstep      = 3;   // ZigZag backstep
input int             LookBackBars     = 200; // Bars to search for pivots
input int             ExtendFutureBars = 100; // Bars to extend trendlines into the future

// Global indicator handle for ZigZag
int zzHandle;

// Arrays for ZigZag data and pivot storage
double   zzBuffer[];
datetime pivotTimes[];
double   pivotPrices[];
bool     pivotIsPeak[];

// Variable to detect new bars
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   zzHandle = iCustom(_Symbol, InpTimeFrame, "ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
   if(zzHandle == INVALID_HANDLE)
     {
      Print("Error creating ZigZag handle");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, "Downtrend_HighLine");
   ObjectDelete(0, "Downtrend_LowLine");
   ObjectDelete(0, "Major_Resistance");
   ObjectDelete(0, "Major_Support");
   ObjectDelete(0, "Minor_Resistance");
   ObjectDelete(0, "Minor_Support");
   IndicatorRelease(zzHandle);
  }

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime currentBarTime = iTime(_Symbol, InpTimeFrame, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;

// Remove previous objects
   ObjectDelete(0, "Downtrend_HighLine");
   ObjectDelete(0, "Downtrend_LowLine");
   ObjectDelete(0, "Major_Resistance");
   ObjectDelete(0, "Major_Support");
   ObjectDelete(0, "Minor_Resistance");
   ObjectDelete(0, "Minor_Support");

   if(CopyBuffer(zzHandle, 0, 0, LookBackBars, zzBuffer) <= 0)
     {
      Print("Failed to copy ZigZag data");
      return;
     }
   ArraySetAsSeries(zzBuffer, true);

   DrawZigZagTrendlines();
   DrawSupportResistance();
  }

//+------------------------------------------------------------------+
//| Draw ZigZag-based Trendlines                                     |
//+------------------------------------------------------------------+
void DrawZigZagTrendlines()
  {
   double highPrices[10], lowPrices[10];
   datetime highTimes[10], lowTimes[10];
   int highCount = 0, lowCount = 0;

// Extract swing points from the ZigZag buffer
   for(int i = 0; i < LookBackBars - 1; i++)
     {
      if(zzBuffer[i] != 0)
        {
         if(iHigh(_Symbol, InpTimeFrame, i) == zzBuffer[i] && highCount < 10)
           {
            highPrices[highCount] = zzBuffer[i];
            highTimes[highCount] = iTime(_Symbol, InpTimeFrame, i);
            highCount++;
           }
         else
            if(iLow(_Symbol, InpTimeFrame, i) == zzBuffer[i] && lowCount < 10)
              {
               lowPrices[lowCount] = zzBuffer[i];
               lowTimes[lowCount] = iTime(_Symbol, InpTimeFrame, i);
               lowCount++;
              }
        }
     }

// Exclude the most recent swing if possible
   int usedHighCount = (highCount >= 4) ? highCount - 1 : highCount;
   int usedLowCount  = (lowCount  >= 4) ? lowCount - 1  : lowCount;

   double mHigh = 0, bHigh = 0, mLow = 0, bLow = 0;
   bool validHigh = false, validLow = false;

// Regression for highs
   if(usedHighCount >= 3)
     {
      double sumT = 0, sumP = 0, sumTP = 0, sumT2 = 0;
      for(int i = 0; i < usedHighCount; i++)
        {
         double t = (double)highTimes[i];
         double p = highPrices[i];
         sumT += t;
         sumP += p;
         sumTP += t * p;
         sumT2 += t * t;
        }
      int N = usedHighCount;
      double denominator = N * sumT2 - sumT * sumT;
      if(denominator != 0)
        {
         mHigh = (N * sumTP - sumT * sumP) / denominator;
         bHigh = (sumP - mHigh * sumT) / N;
        }
      else
         bHigh = sumP / N;
      validHigh = true;
     }

// Regression for lows
   if(usedLowCount >= 3)
     {
      double sumT = 0, sumP = 0, sumTP = 0, sumT2 = 0;
      for(int i = 0; i < usedLowCount; i++)
        {
         double t = (double)lowTimes[i];
         double p = lowPrices[i];
         sumT += t;
         sumP += p;
         sumTP += t * p;
         sumT2 += t * t;
        }
      int N = usedLowCount;
      double denominator = N * sumT2 - sumT * sumT;
      if(denominator != 0)
        {
         mLow = (N * sumTP - sumT * sumP) / denominator;
         bLow = (sumP - mLow * sumT) / N;
        }
      else
         bLow = sumP / N;
      validLow = true;
     }

// Define time limits for trendlines
   datetime pastTime   = iTime(_Symbol, InpTimeFrame, LookBackBars - 1);
   datetime futureTime = lastBarTime + ExtendFutureBars * PeriodSeconds();

// Draw trendlines if both regressions are valid
   if(validHigh && validLow)
     {
      // When slopes have the same sign, use average slope
      if(mHigh * mLow > 0)
        {
         double mParallel = (mHigh + mLow) / 2.0;
         double bHighParallel = highPrices[0] - mParallel * (double)highTimes[0];
         double bLowParallel  = lowPrices[0] - mParallel * (double)lowTimes[0];

         datetime highStartTime = pastTime;
         double highStartPrice  = mParallel * (double)highStartTime + bHighParallel;
         double highEndPrice    = mParallel * (double)futureTime + bHighParallel;
         if(!ObjectCreate(0, "Downtrend_HighLine", OBJ_TREND, 0, highStartTime, highStartPrice, futureTime, highEndPrice))
            Print("Failed to create High Trendline");
         else
           {
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_RAY_LEFT, true);
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_RAY_RIGHT, true);
           }

         datetime lowStartTime = pastTime;
         double lowStartPrice  = mParallel * (double)lowStartTime + bLowParallel;
         double lowEndPrice    = mParallel * (double)futureTime + bLowParallel;
         if(!ObjectCreate(0, "Downtrend_LowLine", OBJ_TREND, 0, lowStartTime, lowStartPrice, futureTime, lowEndPrice))
            Print("Failed to create Low Trendline");
         else
           {
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_RAY_LEFT, true);
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_RAY_RIGHT, true);
           }
        }
      else
        {
         datetime highStartTime = pastTime;
         double highStartPrice  = mHigh * (double)highStartTime + bHigh;
         double highEndPrice    = mHigh * (double)futureTime + bHigh;
         if(!ObjectCreate(0, "Downtrend_HighLine", OBJ_TREND, 0, highStartTime, highStartPrice, futureTime, highEndPrice))
            Print("Failed to create High Trendline");
         else
           {
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_RAY_LEFT, true);
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_RAY_RIGHT, true);
           }

         datetime lowStartTime = pastTime;
         double lowStartPrice  = mLow * (double)lowStartTime + bLow;
         double lowEndPrice    = mLow * (double)futureTime + bLow;
         if(!ObjectCreate(0, "Downtrend_LowLine", OBJ_TREND, 0, lowStartTime, lowStartPrice, futureTime, lowEndPrice))
            Print("Failed to create Low Trendline");
         else
           {
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_RAY_LEFT, true);
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_RAY_RIGHT, true);
           }
        }
     }
   else
     {
      if(validHigh)
        {
         datetime highStartTime = pastTime;
         double highStartPrice  = mHigh * (double)highStartTime + bHigh;
         double highEndPrice    = mHigh * (double)futureTime + bHigh;
         if(!ObjectCreate(0, "Downtrend_HighLine", OBJ_TREND, 0, highStartTime, highStartPrice, futureTime, highEndPrice))
            Print("Failed to create High Trendline");
         else
           {
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_RAY_LEFT, true);
            ObjectSetInteger(0, "Downtrend_HighLine", OBJPROP_RAY_RIGHT, true);
           }
        }
      if(validLow)
        {
         datetime lowStartTime = pastTime;
         double lowStartPrice  = mLow * (double)lowStartTime + bLow;
         double lowEndPrice    = mLow * (double)futureTime + bLow;
         if(!ObjectCreate(0, "Downtrend_LowLine", OBJ_TREND, 0, lowStartTime, lowStartPrice, futureTime, lowEndPrice))
            Print("Failed to create Low Trendline");
         else
           {
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_RAY_LEFT, true);
            ObjectSetInteger(0, "Downtrend_LowLine", OBJPROP_RAY_RIGHT, true);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Draw Support and Resistance Levels                               |
//+------------------------------------------------------------------+
void DrawSupportResistance()
  {
   double confirmedHighs[10], confirmedLows[10];
   int confHighCount = 0, confLowCount = 0;

   for(int i = 0; i < LookBackBars - 1; i++)
     {
      if(zzBuffer[i] != 0)
        {
         if(iHigh(_Symbol, InpTimeFrame, i) == zzBuffer[i] && confHighCount < 10)
           {
            confirmedHighs[confHighCount] = zzBuffer[i];
            confHighCount++;
           }
         else
            if(iLow(_Symbol, InpTimeFrame, i) == zzBuffer[i] && confLowCount < 10)
              {
               confirmedLows[confLowCount] = zzBuffer[i];
               confLowCount++;
              }
        }
     }

   int usedHighCount = (confHighCount >= 4) ? confHighCount - 1 : confHighCount;
   int usedLowCount  = (confLowCount  >= 4) ? confLowCount - 1  : confLowCount;

   double majorResistance = -1e9, majorSupport = 1e9;
   double minorResistance = -1e9, minorSupport = 1e9;
   double tempHigh = -1e9, tempLow = -1e9;
   for(int i = 0; i < usedHighCount; i++)
     {
      if(confirmedHighs[i] > majorResistance)
        {
         tempHigh = majorResistance;
         majorResistance = confirmedHighs[i];
        }
      else
         if(confirmedHighs[i] > tempHigh)
           {
            tempHigh = confirmedHighs[i];
           }
     }
   if(tempHigh > -1e9)
      minorResistance = tempHigh;
   for(int i = 0; i < usedLowCount; i++)
     {
      if(confirmedLows[i] < majorSupport)
        {
         tempLow = majorSupport;
         majorSupport = confirmedLows[i];
        }
      else
         if(confirmedLows[i] < tempLow)
           {
            tempLow = confirmedLows[i];
           }
     }
   if(tempLow < 1e9)
      minorSupport = tempLow;

   if(usedHighCount > 0)
     {
      if(!ObjectCreate(0, "Major_Resistance", OBJ_HLINE, 0, 0, majorResistance))
         Print("Failed to create Major Resistance");
      else
         ObjectSetInteger(0, "Major_Resistance", OBJPROP_COLOR, clrMagenta);

      if(minorResistance > -1e9 && minorResistance < majorResistance)
        {
         if(!ObjectCreate(0, "Minor_Resistance", OBJ_HLINE, 0, 0, minorResistance))
            Print("Failed to create Minor Resistance");
         else
            ObjectSetInteger(0, "Minor_Resistance", OBJPROP_COLOR, clrFuchsia);
        }
     }
   if(usedLowCount > 0)
     {
      if(!ObjectCreate(0, "Major_Support", OBJ_HLINE, 0, 0, majorSupport))
         Print("Failed to create Major Support");
      else
         ObjectSetInteger(0, "Major_Support", OBJPROP_COLOR, clrAqua);

      if(minorSupport < 1e9 && minorSupport > majorSupport)
        {
         if(!ObjectCreate(0, "Minor_Support", OBJ_HLINE, 0, 0, minorSupport))
            Print("Failed to create Minor Support");
         else
            ObjectSetInteger(0, "Minor_Support", OBJPROP_COLOR, clrBlue);
        }
     }
  }
//+------------------------------------------------------------------+
