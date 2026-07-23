//+------------------------------------------------------------------+
//|                                       ICT_AMD_PowerOfThree.mq5    |
//|        ICT AMD Zonalar (Accumulation - Manipulation -             |
//|                          Distribution) / Power of Three           |
//|                                                                   |
//|  Vaqtga (kun boshi/oxiri) bog'liq EMAS. AMD sikllari bar soniga   |
//|  asoslangan holda ketma-ket, yonma-yon chiziladi:                 |
//|    A) Accumulation -> N barlik yig'ilish diapazoni (quti)         |
//|    M) Manipulation -> diapazon high/low ni sindirish (sweep)      |
//|    D) Distribution -> sweepga teskari harakat (target YO'Q)       |
//|  Har bir sikl manipulyatsiyadan keyin darrov yangisi bilan davom  |
//|  etadi. Universal: har qanday instrument va timeframe uchun.      |
//+------------------------------------------------------------------+
#property copyright   "ICT AMD / Power of Three"
#property version     "2.00"
#property description "ICT AMD: ketma-ket Accumulation/Manipulation/Distribution zonalari (bar asosida, vaqtga bog'liq emas, targetsiz)."
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//============================ INPUTS =================================//

input string inf0 = "===== UMUMIY =====";                 // -----
input int    InpHistoryBars    = 1500;  // Tahlil qilinadigan bar soni

input string inf1 = "===== SIKL O'LCHAMLARI (bar) =====";  // -----
input int    InpAccBars        = 20;    // Accumulation uzunligi (bar)
input int    InpScanBars       = 20;    // Manipulyatsiyani izlash oynasi (bar)
input int    InpDistBars       = 12;    // Distribution chizig'i uzunligi (bar)

input string inf2 = "===== ACCUMULATION (A) =====";        // -----
input bool   InpShowAcc        = true;  // Accumulation quti ko'rsatilsinmi
input color  InpAccColor       = clrSlateGray;   // Accumulation rangi

input string inf3 = "===== MANIPULATION (M) =====";        // -----
input bool   InpShowManip      = true;  // Manipulation belgisi
input color  InpManipColor     = clrCrimson;     // Manipulation rangi
input bool   InpAlertOnManip   = false; // Oxirgi sikl manipulyatsiyasida alert

input string inf4 = "===== DISTRIBUTION (D) =====";        // -----
input bool   InpShowDist       = true;  // Distribution chizig'i
input color  InpDistUpColor    = clrTeal;        // Bullish distribution rangi
input color  InpDistDownColor  = clrOrangeRed;   // Bearish distribution rangi

input string inf5 = "===== YORLIQLAR =====";               // -----
input bool   InpShowLabels     = true;  // A / M / D yorliqlari
input int    InpFontSize       = 9;     // Yorliq shrifti o'lchami

//========================== GLOBALS =================================//

string   gPrefix = "AMD_";
datetime gLastBarTime = 0;
int      gId = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "ICT AMD (Power of Three)");
   gLastBarTime = 0;
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, gPrefix);
   ChartRedraw();
}
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
   if(rates_total < InpAccBars + InpScanBars + 5)
      return(rates_total);

   // faqat yangi bar ochilganda qayta chizamiz
   if(time[rates_total-1] == gLastBarTime)
      return(rates_total);
   gLastBarTime = time[rates_total-1];

   ObjectsDeleteAll(0, gPrefix);
   gId = 0;

   int bars  = MathMin(rates_total, InpHistoryBars);
   int start = rates_total - bars;
   if(start < 0) start = 0;

   // eng so'nggi tugallanmagan sikl ekstremumini ham chizamiz -> lastManipSide
   int lastManipSide = 0;

   // --- ketma-ket AMD sikllari ---
   int i = start;
   while(i + InpAccBars < rates_total - 1)
   {
      int accEnd = i + InpAccBars;           // accumulation oxiridan keyingi indeks

      // A) accumulation diapazoni [i, accEnd)
      double accHigh = -DBL_MAX, accLow = DBL_MAX;
      for(int k=i; k<accEnd; k++)
      {
         if(high[k] > accHigh) accHigh = high[k];
         if(low[k]  < accLow)  accLow  = low[k];
      }
      if(accHigh <= accLow){ i = accEnd; continue; }

      if(InpShowAcc)
      {
         DrawRect(accStart_(i), time[i], accHigh, time[accEnd], accLow, InpAccColor, "Accumulation");
         if(InpShowLabels)
            DrawLabel(time[i], accHigh, "A", InpAccColor, ANCHOR_LEFT_LOWER);
      }

      // M) accEnd dan keyingi oynada birinchi sweep + ekstremum
      int    manipSide = 0;         // +1 up sweep, -1 down sweep
      int    manipIdx  = -1;
      double manipPrice = 0;
      int    scanTo = MathMin(accEnd + InpScanBars, rates_total);
      for(int j=accEnd; j<scanTo; j++)
      {
         if(manipSide == 0)
         {
            bool up   = (high[j] > accHigh);
            bool down = (low[j]  < accLow);
            if(up && down)      manipSide = (close[j] < open[j]) ? +1 : -1;
            else if(up)         manipSide = +1;
            else if(down)       manipSide = -1;
            if(manipSide != 0){ manipIdx = j; manipPrice = (manipSide==+1)?high[j]:low[j]; }
         }
         else
         {
            // sweep ekstremumini kuzatamiz (reversgacha)
            if(manipSide==+1 && high[j] > manipPrice){ manipPrice = high[j]; manipIdx = j; }
            if(manipSide==-1 && low[j]  < manipPrice){ manipPrice = low[j];  manipIdx = j; }
         }
      }

      if(manipSide == 0)
      {
         // sweep bo'lmadi -> keyingi sikl shu accumulationdan keyin
         i = accEnd;
         continue;
      }

      if(InpShowManip)
      {
         DrawArrow(time[manipIdx], manipPrice, (manipSide==+1)?234:233, InpManipColor, (manipSide==+1));
         if(InpShowLabels)
            DrawLabel(time[manipIdx], manipPrice, "M", InpManipColor,
                      (manipSide==+1)?ANCHOR_LOWER:ANCHOR_UPPER);
      }

      // D) sweepga teskari harakat (targetsiz -> haqiqiy narx yo'nalishi)
      if(InpShowDist)
      {
         int distEnd = MathMin(manipIdx + InpDistBars, rates_total-1);
         color dCol = (manipSide==+1) ? InpDistDownColor : InpDistUpColor;
         DrawTrend(time[manipIdx], manipPrice, time[distEnd], close[distEnd], dCol);
         if(InpShowLabels)
            DrawLabel(time[distEnd], close[distEnd], "D", dCol,
                      (manipSide==+1)?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
      }

      lastManipSide = manipSide;

      // keyingi sikl darrov manipulyatsiyadan keyin (ketma-ket, yonma-yon)
      i = manipIdx + 1;
   }

   if(InpAlertOnManip && lastManipSide != 0)
      MaybeAlert(lastManipSide);

   ChartRedraw();
   return(rates_total);
}

//============================ DRAW HELPERS ===========================//

string accStart_(int idx){ return "acc_"+(string)idx; }

void DrawRect(string id, datetime t1, double p1, datetime t2, double p2,
              color clr, string tip)
{
   string name = gPrefix + id + "_" + (string)(gId++);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

void DrawTrend(datetime t1, double p1, datetime t2, double p2, color clr)
{
   string name = gPrefix + "d_" + (string)(gId++);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, "Distribution");
}

void DrawArrow(datetime t, double price, int code, color clr, bool above)
{
   string name = gPrefix + "m_" + (string)(gId++);
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, above?ANCHOR_BOTTOM:ANCHOR_TOP);
}

void DrawLabel(datetime t, double price, string txt, color clr, int anchor)
{
   string name = gPrefix + "t_" + (string)(gId++);
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString (0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
}

//+------------------------------------------------------------------+
//| Oxirgi sikl manipulyatsiyasida alert (bir marta)                 |
//+------------------------------------------------------------------+
void MaybeAlert(int side)
{
   static datetime lastAlertBar = 0;
   if(lastAlertBar == gLastBarTime) return;
   lastAlertBar = gLastBarTime;

   string dir = (side==+1) ? "Buy-side sweep -> Bearish distribution kutilmoqda"
                           : "Sell-side sweep -> Bullish distribution kutilmoqda";
   Alert(_Symbol, " ", EnumToString((ENUM_TIMEFRAMES)_Period), " AMD Manipulation: ", dir);
}
//+------------------------------------------------------------------+
