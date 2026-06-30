//+------------------------------------------------------------------+
//|                                             ICT_SmartMoney.mq5    |
//|              ICT / Smart Money Concepts All-in-One Indicator      |
//|                                                                   |
//|  Modullar:                                                        |
//|    1) Market Structure  -> Swing High/Low, BOS, CHoCH             |
//|    2) Order Block + FVG  -> OB zonalari va Fair Value Gap         |
//|    3) Liquidity (BSL/SSL)-> teng high/low va liquidity sweep      |
//|    4) Killzone + Silver Bullet -> savdo seanslari va SB oynasi    |
//|                                                                   |
//|  Universal: har qanday instrument va timeframe uchun.             |
//+------------------------------------------------------------------+
#property copyright   "ICT Smart Money Concepts"
#property version     "1.00"
#property description "ICT/SMC: Market Structure (BOS/CHoCH), Order Block + FVG, Liquidity (BSL/SSL) sweep, Killzone + Silver Bullet."
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//============================ INPUTS =================================//

input string  inf0 = "===== UMUMIY SOZLAMALAR =====";     // -----
input int     InpHistoryBars   = 600;     // Tahlil qilinadigan bar soni
input int     InpSwingStrength  = 3;      // Swing kuchi (chap/o'ng barlar)
input bool    InpAlertsOn       = false;  // Signal (alert) yoqilsinmi

input string  inf1 = "===== 1) MARKET STRUCTURE =====";   // -----
input bool    InpShowStructure  = true;   // Market Structure ko'rsatilsinmi (BOS/CHoCH)
input color   InpBosColor       = clrDodgerBlue;   // BOS chizig'i rangi
input color   InpChochColor     = clrOrange;       // CHoCH chizig'i rangi
input bool    InpShowSwings     = true;            // Swing nuqtalari (HH/HL/LH/LL)

input string  inf2 = "===== 2) ORDER BLOCK + FVG =====";  // -----
input bool    InpShowOB         = true;   // Order Block ko'rsatilsinmi
input color   InpBullOBColor    = clrTeal;         // Bullish OB rangi
input color   InpBearOBColor    = clrFireBrick;    // Bearish OB rangi
input bool    InpShowFVG        = true;            // Fair Value Gap ko'rsatilsinmi
input color   InpBullFVGColor   = clrSeaGreen;     // Bullish FVG rangi
input color   InpBearFVGColor   = clrIndianRed;    // Bearish FVG rangi
input int     InpMaxOB          = 8;               // Maksimal OB/FVG soni (har turdan)

input string  inf3 = "===== 3) LIQUIDITY (BSL/SSL) ====="; // -----
input bool    InpShowLiquidity  = true;   // Liquidity (teng high/low) ko'rsatilsinmi
input double  InpEqTolerancePts = 0;      // Teng daraja toleransi (punkt, 0=avto)
input color   InpBSLColor       = clrSilver;       // Buy-side liquidity rangi
input color   InpSSLColor       = clrSilver;       // Sell-side liquidity rangi
input bool    InpShowSweep      = true;            // Liquidity sweep belgilansinmi
input color   InpSweepColor     = clrMagenta;      // Sweep belgisi rangi

input string  inf4 = "===== 4) KILLZONE + SILVER BULLET ====="; // -----
input bool    InpShowKillzones  = true;   // Killzone seanslari ko'rsatilsinmi
input int     InpGmtOffset      = 0;      // Broker server vaqti GMT ofseti (soat)
input color   InpAsiaColor      = clrGray;         // Asian killzone rangi
input color   InpLondonColor    = clrRoyalBlue;    // London killzone rangi
input color   InpNYColor        = clrDarkOrange;   // New York killzone rangi
input bool    InpShowSilver     = true;            // Silver Bullet oynasi (NY 10:00-11:00)
input color   InpSilverColor    = clrGold;         // Silver Bullet rangi

//========================== GLOBALS =================================//

string  gPrefix = "ICT_";   // barcha obyektlar prefiksi

// swing buferlari (oxirgi tasdiqlangan swinglar)
double  gLastSwingHigh   = 0.0;
double  gLastSwingLow    = 0.0;
datetime gLastSwingHighT = 0;
datetime gLastSwingLowT  = 0;

// market structure holati: +1 bullish, -1 bearish, 0 noaniq
int     gTrend = 0;

// trend buzilishlarini takror chizmaslik uchun
double  gBrokenHigh = 0.0;
double  gBrokenLow  = 0.0;

datetime gLastBarTime = 0;
int      gObjCounter  = 0;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "ICT Smart Money");
   gLastBarTime = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, gPrefix);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculate                                                        |
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
   if(rates_total < 50)
      return(rates_total);

   // faqat yangi bar ochilganda qayta hisoblaymiz (tezlik uchun)
   if(time[rates_total-1] == gLastBarTime)
      return(rates_total);
   gLastBarTime = time[rates_total-1];

   // eski obyektlarni tozalaymiz va qaytadan chizamiz
   ObjectsDeleteAll(0, gPrefix);
   gObjCounter = 0;
   gTrend      = 0;
   gLastSwingHigh = 0; gLastSwingLow = 0;
   gBrokenHigh = 0;    gBrokenLow = 0;

   int bars = MathMin(rates_total, InpHistoryBars);
   int start = rates_total - bars;
   if(start < InpSwingStrength+1)
      start = InpSwingStrength+1;

   // 1) MARKET STRUCTURE (+ OB/FVG triggerlari shu yerda)
   ProcessStructure(rates_total, start, time, open, high, low, close);

   // 3) LIQUIDITY
   if(InpShowLiquidity)
      ProcessLiquidity(rates_total, start, time, high, low, close);

   // 4) KILLZONES
   if(InpShowKillzones)
      ProcessKillzones(rates_total, start, time, high, low);

   ChartRedraw();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Swing high fraktalmi? (i markaziy bar, global indeks)            |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &high[], int i, int rates_total, int s)
{
   if(i-s < 0 || i+s >= rates_total)
      return(false);
   double v = high[i];
   for(int k=1; k<=s; k++)
      if(high[i-k] >= v || high[i+k] >= v)
         return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Swing low fraktalmi?                                             |
//+------------------------------------------------------------------+
bool IsSwingLow(const double &low[], int i, int rates_total, int s)
{
   if(i-s < 0 || i+s >= rates_total)
      return(false);
   double v = low[i];
   for(int k=1; k<=s; k++)
      if(low[i-k] <= v || low[i+k] <= v)
         return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| 1) MARKET STRUCTURE: swing, BOS, CHoCH (+ OB/FVG triggeri)       |
//+------------------------------------------------------------------+
void ProcessStructure(int rates_total, int start,
                      const datetime &time[], const double &open[],
                      const double &high[], const double &low[],
                      const double &close[])
{
   int s = InpSwingStrength;

   // o'ng tomonda s ta tasdiq bar kerak -> rates_total-s gacha
   for(int i=start; i<rates_total-s; i++)
   {
      // --- yangi swing high topildi ---
      if(IsSwingHigh(high, i, rates_total, s))
      {
         // swing belgisi (HH/LH)
         if(InpShowSwings)
         {
            string lab = (gLastSwingHigh>0 && high[i]>gLastSwingHigh) ? "HH" : "LH";
            DrawText("sw", time[i], high[i], lab, clrGray, false);
         }
         gLastSwingHigh   = high[i];
         gLastSwingHighT  = time[i];
      }

      // --- yangi swing low topildi ---
      if(IsSwingLow(low, i, rates_total, s))
      {
         if(InpShowSwings)
         {
            string lab = (gLastSwingLow>0 && low[i]<gLastSwingLow) ? "LL" : "HL";
            DrawText("sw", time[i], low[i], lab, clrGray, true);
         }
         gLastSwingLow   = low[i];
         gLastSwingLowT  = time[i];
      }

      // --- struktura buzilishini joriy bar yopilishi bilan tekshiramiz ---
      // Bullish: yuqoridagi oxirgi swing high ustida yopilish
      if(gLastSwingHigh>0 && close[i] > gLastSwingHigh && gLastSwingHigh != gBrokenHigh)
      {
         bool isChoch = (gTrend < 0);   // oldin bearish bo'lsa CHoCH
         if(InpShowStructure)
         {
            color c = isChoch ? InpChochColor : InpBosColor;
            DrawStructureLine("ms", gLastSwingHighT, gLastSwingHigh, time[i],
                              isChoch ? "CHoCH" : "BOS", c, true);
         }
         if(InpShowOB || InpShowFVG)
            FindBullishOB_FVG(rates_total, i, time, open, high, low, close);

         if(InpAlertsOn && i >= rates_total-2)   // faqat eng so'nggi bar uchun
            DoAlert((isChoch?"CHoCH ":"BOS ")+"Bullish @ "+DoubleToString(gLastSwingHigh,_Digits));

         gTrend      = 1;
         gBrokenHigh = gLastSwingHigh;
      }

      // Bearish: pastdagi oxirgi swing low ostida yopilish
      if(gLastSwingLow>0 && close[i] < gLastSwingLow && gLastSwingLow != gBrokenLow)
      {
         bool isChoch = (gTrend > 0);
         if(InpShowStructure)
         {
            color c = isChoch ? InpChochColor : InpBosColor;
            DrawStructureLine("ms", gLastSwingLowT, gLastSwingLow, time[i],
                              isChoch ? "CHoCH" : "BOS", c, false);
         }
         if(InpShowOB || InpShowFVG)
            FindBearishOB_FVG(rates_total, i, time, open, high, low, close);

         if(InpAlertsOn && i >= rates_total-2)   // faqat eng so'nggi bar uchun
            DoAlert((isChoch?"CHoCH ":"BOS ")+"Bearish @ "+DoubleToString(gLastSwingLow,_Digits));

         gTrend     = -1;
         gBrokenLow = gLastSwingLow;
      }
   }
}

//+------------------------------------------------------------------+
//| 2) Bullish OB + FVG: impuls oldidagi oxirgi pasayuvchi sham      |
//+------------------------------------------------------------------+
void FindBullishOB_FVG(int rates_total, int breakIdx,
                       const datetime &time[], const double &open[],
                       const double &high[], const double &low[],
                       const double &close[])
{
   datetime rightEdge = time[rates_total-1] + (time[rates_total-1]-time[rates_total-2])*10;

   // Bullish OB: buzilishdan oldingi oxirgi bearish (close<open) sham
   if(InpShowOB)
   {
      for(int j=breakIdx-1; j>=MathMax(0,breakIdx-20); j--)
      {
         if(close[j] < open[j])   // bearish sham = bullish order block
         {
            DrawZone("ob", time[j], low[j], rightEdge, high[j],
                     InpBullOBColor, "Bull OB");
            CleanupExcess("ob_bull", InpMaxOB);
            break;
         }
      }
   }

   // Bullish FVG: 3 shamli imbalance, low[k-1] > high[k+1]
   if(InpShowFVG)
   {
      for(int k=breakIdx-1; k>=MathMax(1,breakIdx-15); k--)
      {
         if(k+1 < rates_total && low[k+1] > high[k-1])
         {
            DrawZone("fvg", time[k-1], high[k-1], rightEdge, low[k+1],
                     InpBullFVGColor, "FVG");
            CleanupExcess("fvg_bull", InpMaxOB);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 2) Bearish OB + FVG                                              |
//+------------------------------------------------------------------+
void FindBearishOB_FVG(int rates_total, int breakIdx,
                       const datetime &time[], const double &open[],
                       const double &high[], const double &low[],
                       const double &close[])
{
   datetime rightEdge = time[rates_total-1] + (time[rates_total-1]-time[rates_total-2])*10;

   if(InpShowOB)
   {
      for(int j=breakIdx-1; j>=MathMax(0,breakIdx-20); j--)
      {
         if(close[j] > open[j])   // bullish sham = bearish order block
         {
            DrawZone("ob", time[j], low[j], rightEdge, high[j],
                     InpBearOBColor, "Bear OB");
            CleanupExcess("ob_bear", InpMaxOB);
            break;
         }
      }
   }

   // Bearish FVG: high[k-1] < low[k+1]
   if(InpShowFVG)
   {
      for(int k=breakIdx-1; k>=MathMax(1,breakIdx-15); k--)
      {
         if(k+1 < rates_total && high[k+1] < low[k-1])
         {
            DrawZone("fvg", time[k-1], low[k-1], rightEdge, high[k+1],
                     InpBearFVGColor, "FVG");
            CleanupExcess("fvg_bear", InpMaxOB);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 3) LIQUIDITY: teng high/low (BSL/SSL) va sweep                   |
//+------------------------------------------------------------------+
void ProcessLiquidity(int rates_total, int start,
                      const datetime &time[], const double &high[],
                      const double &low[], const double &close[])
{
   int s = InpSwingStrength;
   double tol;
   if(InpEqTolerancePts > 0)
   {
      // foydalanuvchi bergan toleransa (punktda)
      tol = InpEqTolerancePts * _Point;
   }
   else
   {
      // avto: oxirgi 50 barning o'rtacha diapazonidan 15%
      double rngSum = 0; int cnt = 0;
      for(int i=MathMax(1,rates_total-50); i<rates_total-1; i++){ rngSum += (high[i]-low[i]); cnt++; }
      tol = (cnt>0) ? (rngSum/cnt)*0.15 : 10*_Point;
   }
   if(tol <= 0) tol = 10*_Point;

   datetime rightEdge = time[rates_total-1] + (time[rates_total-1]-time[rates_total-2])*10;

   double lastHigh = 0; datetime lastHighT = 0;
   double lastLow  = 0; datetime lastLowT  = 0;

   for(int i=start; i<rates_total-s; i++)
   {
      // teng HIGH lar -> Buy-side liquidity (BSL)
      if(IsSwingHigh(high, i, rates_total, s))
      {
         if(lastHigh>0 && MathAbs(high[i]-lastHigh) <= tol)
         {
            double lvl = MathMax(high[i], lastHigh);
            DrawLiquidityLine("bsl", lastHighT, lvl, rightEdge, InpBSLColor, "BSL");
            // sweep: keyingi barlarda wick darajadan oshib, yopilishi pastda
            if(InpShowSweep)
               CheckSweep(rates_total, i, lvl, time, high, low, close, true);
         }
         lastHigh = high[i]; lastHighT = time[i];
      }

      // teng LOW lar -> Sell-side liquidity (SSL)
      if(IsSwingLow(low, i, rates_total, s))
      {
         if(lastLow>0 && MathAbs(low[i]-lastLow) <= tol)
         {
            double lvl = MathMin(low[i], lastLow);
            DrawLiquidityLine("ssl", lastLowT, lvl, rightEdge, InpSSLColor, "SSL");
            if(InpShowSweep)
               CheckSweep(rates_total, i, lvl, time, high, low, close, false);
         }
         lastLow = low[i]; lastLowT = time[i];
      }
   }
}

//+------------------------------------------------------------------+
//| Liquidity sweep tekshiruvi                                       |
//+------------------------------------------------------------------+
void CheckSweep(int rates_total, int fromIdx, double level,
                const datetime &time[], const double &high[],
                const double &low[], const double &close[], bool buySide)
{
   for(int n=fromIdx+1; n<MathMin(rates_total, fromIdx+8); n++)
   {
      if(buySide)
      {
         if(high[n] > level && close[n] < level)  // wick yuqoriga, yopilish pastda
         {
            DrawArrow("sweep", time[n], high[n], 234, InpSweepColor, true);
            return;
         }
      }
      else
      {
         if(low[n] < level && close[n] > level)
         {
            DrawArrow("sweep", time[n], low[n], 233, InpSweepColor, false);
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 4) KILLZONES + Silver Bullet (server vaqti bo'yicha)             |
//+------------------------------------------------------------------+
void ProcessKillzones(int rates_total, int start,
                      const datetime &time[], const double &high[],
                      const double &low[])
{
   // GMT bo'yicha killzone soatlari (boshlanish, tugash)
   // Asian 00-06, London 07-10, NY 12-15, Silver Bullet NY 14-15 (10-11 EST ~ 14-15 GMT)
   int asiaB=0,  asiaE=6;
   int lonB=7,   lonE=10;
   int nyB=12,   nyE=15;
   int sbB=14,   sbE=15;

   // har bir yangi kun uchun seans qutilarini bir marta chizamiz
   datetime curDay = 0;
   for(int i=start; i<rates_total; i++)
   {
      datetime dayStart = time[i] - (time[i] % 86400);
      if(dayStart == curDay) continue;
      curDay = dayStart;

      DrawSessionBox(rates_total, start, "kz_asia",  i, asiaB, asiaE, time, high, low, InpAsiaColor,   "Asia");
      DrawSessionBox(rates_total, start, "kz_lon",   i, lonB,  lonE,  time, high, low, InpLondonColor, "London");
      DrawSessionBox(rates_total, start, "kz_ny",    i, nyB,   nyE,   time, high, low, InpNYColor,     "NY");
      if(InpShowSilver)
         DrawSessionBox(rates_total, start, "kz_sb", i, sbB, sbE, time, high, low, InpSilverColor, "Silver Bullet");
   }
}

//+------------------------------------------------------------------+
//| Bitta seans qutisini chizish (shu kundagi soat oralig'i)         |
//+------------------------------------------------------------------+
void DrawSessionBox(int rates_total, int start, string tag, int dayIdx,
                    int hourBegin, int hourEnd,
                    const datetime &time[], const double &high[],
                    const double &low[], color clr, string label)
{
   datetime dayStart = time[dayIdx] - (time[dayIdx] % 86400);
   datetime t1 = dayStart + (datetime)((hourBegin + InpGmtOffset)*3600);
   datetime t2 = dayStart + (datetime)((hourEnd   + InpGmtOffset)*3600);

   double hi = -DBL_MAX, lo = DBL_MAX;
   bool found = false;
   for(int i=start; i<rates_total; i++)
   {
      if(time[i] >= t1 && time[i] < t2)
      {
         if(high[i] > hi) hi = high[i];
         if(low[i]  < lo) lo = low[i];
         found = true;
      }
      if(time[i] >= t2) break;
   }
   if(!found) return;

   string name = gPrefix + tag + "_" + (string)dayStart;
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, label);
   // seans nomi
   string tn = name + "_txt";
   ObjectCreate(0, tn, OBJ_TEXT, 0, t1, hi);
   ObjectSetString (0, tn, OBJPROP_TEXT, label);
   ObjectSetInteger(0, tn, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, tn, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
}

//============================ DRAW HELPERS ===========================//

//+------------------------------------------------------------------+
//| Zona (to'rtburchak) chizish                                      |
//+------------------------------------------------------------------+
void DrawZone(string tag, datetime t1, double p1, datetime t2, double p2,
              color clr, string label)
{
   // CleanupExcess uchun obyektni rangiga qarab turkumlaymiz
   string sub = tag;
   if(tag=="fvg") sub = (clr==InpBullFVGColor) ? "fvg_bull" : "fvg_bear";
   if(tag=="ob")  sub = (clr==InpBullOBColor)  ? "ob_bull"  : "ob_bear";

   string name = gPrefix + sub + "_" + (string)(gObjCounter++);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, label);

   string tn = name + "_txt";
   ObjectCreate(0, tn, OBJ_TEXT, 0, t1, (p1>p2?p1:p2));
   ObjectSetString (0, tn, OBJPROP_TEXT, " "+label);
   ObjectSetInteger(0, tn, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, tn, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
}

//+------------------------------------------------------------------+
//| Struktura chizig'i (BOS/CHoCH gorizontal nuqtali chiziq)         |
//+------------------------------------------------------------------+
void DrawStructureLine(string tag, datetime t1, double price, datetime t2,
                       string label, color clr, bool bullish)
{
   string name = gPrefix + tag + "_" + (string)(gObjCounter++);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, label);

   string tn = name + "_txt";
   ObjectCreate(0, tn, OBJ_TEXT, 0, t2, price);
   ObjectSetString (0, tn, OBJPROP_TEXT, " "+label);
   ObjectSetInteger(0, tn, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, tn, OBJPROP_ANCHOR, bullish?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Liquidity gorizontal chizig'i                                    |
//+------------------------------------------------------------------+
void DrawLiquidityLine(string tag, datetime t1, double price, datetime t2,
                       color clr, string label)
{
   string name = gPrefix + tag + "_" + (string)(gObjCounter++);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, label);

   string tn = name + "_txt";
   ObjectCreate(0, tn, OBJ_TEXT, 0, t2, price);
   ObjectSetString (0, tn, OBJPROP_TEXT, " "+label);
   ObjectSetInteger(0, tn, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, tn, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Matn yorlig'i                                                    |
//+------------------------------------------------------------------+
void DrawText(string tag, datetime t, double price, string txt, color clr, bool below)
{
   string name = gPrefix + tag + "_" + (string)(gObjCounter++);
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString (0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, below?ANCHOR_UPPER:ANCHOR_LOWER);
}

//+------------------------------------------------------------------+
//| Strelka (arrow code) chizish                                     |
//+------------------------------------------------------------------+
void DrawArrow(string tag, datetime t, double price, int code, color clr, bool above)
{
   string name = gPrefix + tag + "_" + (string)(gObjCounter++);
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, above?ANCHOR_BOTTOM:ANCHOR_TOP);
}

//+------------------------------------------------------------------+
//| Ortiqcha obyektlarni o'chirish (eng eskilarini)                  |
//+------------------------------------------------------------------+
void CleanupExcess(string sub, int maxKeep)
{
   string pat = gPrefix + sub + "_";
   // shu turdagi (asosiy, _txt emas) obyektlarni sanaymiz
   int count = 0;
   int total = ObjectsTotal(0);
   for(int i=total-1; i>=0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, pat) == 0 && StringFind(nm, "_txt") < 0)
         count++;
   }
   // eng eskilarini (nom ichidagi counter eng kichigi) o'chiramiz
   while(count > maxKeep)
   {
      long   oldestId   = LONG_MAX;
      string oldestName = "";
      int tt = ObjectsTotal(0);
      for(int i=0; i<tt; i++)
      {
         string nm = ObjectName(0, i);
         if(StringFind(nm, pat) == 0 && StringFind(nm, "_txt") < 0)
         {
            string idStr = StringSubstr(nm, StringLen(pat));
            long id = StringToInteger(idStr);
            if(id < oldestId){ oldestId = id; oldestName = nm; }
         }
      }
      if(oldestName=="") break;
      ObjectDelete(0, oldestName);
      ObjectDelete(0, oldestName+"_txt");
      count--;
   }
}

//+------------------------------------------------------------------+
//| Alert yuborish (takrorni oldini olish bilan)                     |
//+------------------------------------------------------------------+
void DoAlert(string msg)
{
   static string lastMsg = "";
   if(msg == lastMsg) return;
   lastMsg = msg;
   Alert(_Symbol, " ", EnumToString((ENUM_TIMEFRAMES)_Period), ": ", msg);
}
//+------------------------------------------------------------------+
