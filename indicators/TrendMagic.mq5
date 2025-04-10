//+------------------------------------------------------------------+
//|                                                   TrendMagic.mq5 |
//|                                                   Vivek Arora |
//|                                               vivekarora208@gmail.com |
//+------------------------------------------------------------------+
#property copyright " Vivek Arora "
#property link      "vivekarora208@gmail.com"
#property version   "1.00"
//--- indicator properties
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1 Blue,Red
#property indicator_width1 2
//--- input parameters
input int CCI_Period = 40;
input int ATR_Period = 150;
//--- arrays for indicator buffers
double Buffer[];
double Color[];
double CCI[];
double ATR[];
//--- variables to store handles of the indicators
int Hcci = INVALID_HANDLE;
int Hatr = INVALID_HANDLE;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- prepare buffers
   SetIndexBuffer(0,Buffer,INDICATOR_DATA);
   SetIndexBuffer(1,Color,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,CCI,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,ATR,INDICATOR_CALCULATIONS);
//--- initialize buffers
   ArrayInitialize(Buffer,0.0);
   ArrayInitialize(CCI,0.0);
   ArrayInitialize(ATR,0.0);
//--- indicator buffers mapping
   Hcci=iCCI(_Symbol,_Period,CCI_Period,PRICE_TYPICAL);
   Hatr=iATR(_Symbol,_Period,ATR_Period);
//---
   return(0);
  }
  
void OnDeinit(const int reason)
{
    //--- Release ATR handle to free resources ---
    IndicatorRelease(Hcci);
    IndicatorRelease(Hatr);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- check number of bars, necessary for the calculation
   if(rates_total<CCI_Period || rates_total<ATR_Period) return(rates_total);
   
   ArrayResize(Buffer,rates_total,2);
//--- check handles of the indicators
   if(Hcci==INVALID_HANDLE || Hcci==0)
     {
      Hcci=iCCI(_Symbol,_Period,CCI_Period,PRICE_TYPICAL);
      return(rates_total);
     }
   if(Hatr==INVALID_HANDLE || Hatr==0)
     {
      Hatr=iATR(_Symbol,_Period,ATR_Period);
      return(rates_total);
     }
//--- check number of calculated data
   int calculated1=BarsCalculated(Hcci);
   int calculated2=BarsCalculated(Hatr);
//--- synchronize data
   int to_copy=MathMin(calculated1,calculated2);
   if(to_copy<0)return(rates_total);
//--- copy data of the indicators
   if(CopyBuffer(Hcci,0,0,to_copy,CCI)<to_copy)return(rates_total);
   if(CopyBuffer(Hatr,0,0,to_copy,ATR)<to_copy)return(rates_total);
//--- set arrays as time series
   ArraySetAsSeries(CCI,true);
   ArraySetAsSeries(ATR,true);
   ArraySetAsSeries(Buffer,true);
   ArraySetAsSeries(Color,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(high,true);
//--- calculate and write data to the indicator's buffer
   for(int i=rates_total-2; i>=0; i--)
     {
      if(CCI[i]>=0.0)
        {
         Buffer[i]=low[i]-ATR[i];
         if(Buffer[i]<Buffer[i+1])Buffer[i]=Buffer[i+1];
         Color[i]=0.0;
        }
      else if(CCI[i]<0.0)
        {
         Buffer[i]=high[i]+ATR[i];
         if(Buffer[i]>Buffer[i+1])Buffer[i]=Buffer[i+1];
         Color[i]=1.0;
        }
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
