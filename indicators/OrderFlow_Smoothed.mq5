
//------------------------------------------------------------------
#property copyright   "© mladen, 2018"
#property link        "mladenfx@gmail.com"
#property version     "1.00"
#property description "Smooth MFI"
//------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_label1  "Smooth MFI"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDodgerBlue,clrSandyBrown
#property indicator_width1  2
#property indicator_maximum 100.0
#property indicator_minimum 0.0
#property indicator_level1  20.0
#property indicator_level2  80.0
//
//--- input parameters
//
input int                 inpMfiPeriod  = 14;          // MFI period
input int                 inpSmoPeriod  = 14;          // Smoothing period
input ENUM_APPLIED_VOLUME inpVolumeType = VOLUME_TICK; // Volumes
//
//--- indicator buffers
//
double val[],valc[];
//------------------------------------------------------------------
// Custom indicator initialization function
//------------------------------------------------------------------
int OnInit()
{
   SetIndexBuffer(0,val,INDICATOR_DATA);
   SetIndexBuffer(1,valc,INDICATOR_COLOR_INDEX);
//---
   IndicatorSetString(INDICATOR_SHORTNAME,"Smoothed MFI ("+(string)inpMfiPeriod+","+(string)inpSmoPeriod+")");
   return(INIT_SUCCEEDED);
}
//------------------------------------------------------------------
// Custom indicator de-initialization function
//------------------------------------------------------------------
void OnDeinit(const int reason) { return; }
//------------------------------------------------------------------
// Custom iteration function
//------------------------------------------------------------------
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{                
   if (Bars(_Symbol,_Period)<rates_total) return(-1);
  
   //
   //---
   //

   for (int i=(int)MathMax(prev_calculated-1,0); i<rates_total && !_StopFlag; i++)
   {
      double dPositiveMF=0.0;
      double dNegativeMF=0.0;
      double dCurrentTP=(high[i]+low[i]+close[i])/3;
      for(int j=0; j<inpMfiPeriod && (i-j-1)>=0; j++)
        {
         double dPreviousTP=(high[i-j-1]+low[i-j-1]+close[i-j-1])/3.0;
            if(dCurrentTP>dPreviousTP) dPositiveMF+=(inpVolumeType==VOLUME_TICK?tick_volume[i-j]:volume[i-j])*dCurrentTP;
            if(dCurrentTP<dPreviousTP) dNegativeMF+=(inpVolumeType==VOLUME_TICK?tick_volume[i-j]:volume[i-j])*dCurrentTP;
               dCurrentTP=dPreviousTP;
        }
      val[i]  = iSmooth((dNegativeMF!=0.0) ? 100.0-100.0/(1.0+dPositiveMF/dNegativeMF) : 100.0,inpSmoPeriod,0,i,rates_total);
      valc[i] = (i>0) ? (val[i]<val[i-1]) : 0 ;
   }          
   return(rates_total);
}

//+------------------------------------------------------------------
//| Custom functions
//+------------------------------------------------------------------
#define _smoothInstances     1
#define _smoothInstancesSize 10
double m_wrk[][_smoothInstances*_smoothInstancesSize];
int    m_size=0;
//
//---
//
double iSmooth(double price,double length,double phase,int r,int bars,int instanceNo=0)
  {
   #define bsmax  5
   #define bsmin  6
   #define volty  7
   #define vsum   8
   #define avolty 9

   if(ArrayRange(m_wrk,0)!=bars) ArrayResize(m_wrk,bars); if(ArrayRange(m_wrk,0)!=bars) return(price); instanceNo*=_smoothInstancesSize;
   if(r==0 || length<=1) { int k=0; for(; k<7; k++) m_wrk[r][instanceNo+k]=price; for(; k<10; k++) m_wrk[r][instanceNo+k]=0; return(price); }

//
//---
//

   double len1   = MathMax(MathLog(MathSqrt(0.5*(length-1)))/MathLog(2.0)+2.0,0);
   double pow1   = MathMax(len1-2.0,0.5);
   double del1   = price - m_wrk[r-1][instanceNo+bsmax];
   double del2   = price - m_wrk[r-1][instanceNo+bsmin];
   int    forBar = MathMin(r,10);

   m_wrk[r][instanceNo+volty]=0;
   if(MathAbs(del1) > MathAbs(del2)) m_wrk[r][instanceNo+volty] = MathAbs(del1);
   if(MathAbs(del1) < MathAbs(del2)) m_wrk[r][instanceNo+volty] = MathAbs(del2);
   m_wrk[r][instanceNo+vsum]=m_wrk[r-1][instanceNo+vsum]+(m_wrk[r][instanceNo+volty]-m_wrk[r-forBar][instanceNo+volty])*0.1;

//
//---
//

   m_wrk[r][instanceNo+avolty]=m_wrk[r-1][instanceNo+avolty]+(2.0/(MathMax(4.0*length,30)+1.0))*(m_wrk[r][instanceNo+vsum]-m_wrk[r-1][instanceNo+avolty]);
   double dVolty=(m_wrk[r][instanceNo+avolty]>0) ? m_wrk[r][instanceNo+volty]/m_wrk[r][instanceNo+avolty]: 0;
   if(dVolty > MathPow(len1,1.0/pow1)) dVolty = MathPow(len1,1.0/pow1);
   if(dVolty < 1)                      dVolty = 1.0;

//
//---
//

   double pow2 = MathPow(dVolty, pow1);
   double len2 = MathSqrt(0.5*(length-1))*len1;
   double Kv   = MathPow(len2/(len2+1), MathSqrt(pow2));

   if(del1 > 0) m_wrk[r][instanceNo+bsmax] = price; else m_wrk[r][instanceNo+bsmax] = price - Kv*del1;
   if(del2 < 0) m_wrk[r][instanceNo+bsmin] = price; else m_wrk[r][instanceNo+bsmin] = price - Kv*del2;

//
//---
//

   double corr  = MathMax(MathMin(phase,100),-100)/100.0 + 1.5;
   double beta  = 0.45*(length-1)/(0.45*(length-1)+2);
   double alpha = MathPow(beta,pow2);

   m_wrk[r][instanceNo+0] = price + alpha*(m_wrk[r-1][instanceNo+0]-price);
   m_wrk[r][instanceNo+1] = (price - m_wrk[r][instanceNo+0])*(1-beta) + beta*m_wrk[r-1][instanceNo+1];
   m_wrk[r][instanceNo+2] = (m_wrk[r][instanceNo+0] + corr*m_wrk[r][instanceNo+1]);
   m_wrk[r][instanceNo+3] = (m_wrk[r][instanceNo+2] - m_wrk[r-1][instanceNo+4])*MathPow((1-alpha),2) + MathPow(alpha,2)*m_wrk[r-1][instanceNo+3];
   m_wrk[r][instanceNo+4] = (m_wrk[r-1][instanceNo+4] + m_wrk[r][instanceNo+3]);

//
//---
//

   return(m_wrk[r][instanceNo+4]);

   #undef bsmax
   #undef bsmin
   #undef volty
   #undef vsum
   #undef avolty
  }    

