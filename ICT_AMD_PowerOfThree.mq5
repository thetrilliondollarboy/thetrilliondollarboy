//+------------------------------------------------------------------+
//|                                       ICT_AMD_PowerOfThree.mq5    |
//|        ICT AMD Zonalar (Accumulation - Manipulation -             |
//|                          Distribution) / Power of Three           |
//|                                                                   |
//|  Har bir savdo kuni uchun:                                        |
//|    A) Accumulation -> Osiyo/belgilangan oynada yig'ilish diapazoni|
//|    M) Manipulation -> diapazon high/low ni yolg'on sindirish      |
//|                       (liquidity grab / stop hunt)                |
//|    D) Distribution -> teskari asosiy harakat + proyeksiya (target)|
//|                                                                   |
//|  Universal: har qanday instrument va timeframe uchun.             |
//+------------------------------------------------------------------+
#property copyright   "ICT AMD / Power of Three"
#property version     "1.00"
#property description "ICT AMD: Accumulation quti, Manipulation (liquidity sweep) va Distribution proyeksiyasi. Power of Three modeli."
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//============================ INPUTS =================================//

input string inf0 = "===== UMUMIY =====";                 // -----
input int    InpHistoryBars   = 2000;   // Tahlil qilinadigan bar soni
input int    InpMaxDays        = 20;    // Nechta kun chizilsin (oxirgi)
input int    InpGmtOffset      = 0;     // Broker server vaqti GMT ofseti (soat)

input string inf1 = "===== VAQT OYNALARI (GMT) =====";     // -----
input int    InpAccStartHour   = 0;     // Accumulation boshlanishi (GMT soat)
input int    InpAccEndHour     = 7;     // Accumulation tugashi (GMT soat)
input int    InpDayEndHour     = 20;    // Savdo kuni tugashi (M/D oynasi, GMT)

input string inf2 = "===== ACCUMULATION (A) =====";        // -----
input bool   InpShowAcc        = true;  // Accumulation quti ko'rsatilsinmi
input color  InpAccColor       = clrSlateGray;   // Accumulation rangi

input string inf3 = "===== MANIPULATION (M) =====";        // -----
input bool   InpShowManip      = true;  // Manipulation belgisi
input color  InpManipColor     = clrCrimson;     // Manipulation rangi
input bool   InpAlertOnManip   = false; // Manipulation yuz berganda alert

input string inf4 = "===== DISTRIBUTION (D) =====";        // -----
input bool   InpShowDist       = true;  // Distribution proyeksiyasi
input color  InpDistUpColor    = clrTeal;        // Bullish distribution rangi
input color  InpDistDownColor  = clrOrangeRed;   // Bearish distribution rangi
input bool   InpShowTarget     = true;  // Target (nishon) chizig'i
input double InpTargetRatio    = 1.0;   // Target = diapazon x shu nisbat

input string inf5 = "===== YORLIQLAR =====";               // -----
input bool   InpShowLabels     = true;  // A / M / D yorliqlari
input int    InpFontSize       = 9;     // Yorliq shrifti o'lchami

//========================== GLOBALS =================================//

string   gPrefix = "AMD_";
datetime gLastBarTime = 0;

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
   if(rates_total < 50)
      return(rates_total);

   // faqat yangi bar ochilganda qayta chizamiz
   if(time[rates_total-1] == gLastBarTime)
      return(rates_total);
   gLastBarTime = time[rates_total-1];

   ObjectsDeleteAll(0, gPrefix);

   int bars  = MathMin(rates_total, InpHistoryBars);
   int start = rates_total - bars;
   if(start < 1) start = 1;

   // faqat oxirgi InpMaxDays kunni chizamiz
   datetime lastDay = time[rates_total-1] - (time[rates_total-1] % 86400);
   datetime minDay  = lastDay - (datetime)(InpMaxDays-1)*86400;

   datetime curDay = 0;
   for(int i=start; i<rates_total; i++)
   {
      datetime dayStart = time[i] - (time[i] % 86400);
      if(dayStart == curDay) continue;
      curDay = dayStart;
      if(dayStart < minDay) continue;

      ProcessAMDDay(rates_total, start, dayStart, time, open, high, low, close);
   }

   ChartRedraw();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Bitta kun uchun AMD modelini qayta ishlash                       |
//+------------------------------------------------------------------+
void ProcessAMDDay(int rates_total, int start, datetime dayStart,
                   const datetime &time[], const double &open[],
                   const double &high[], const double &low[],
                   const double &close[])
{
   datetime accStart = dayStart + (datetime)((InpAccStartHour + InpGmtOffset)*3600);
   datetime accEnd   = dayStart + (datetime)((InpAccEndHour   + InpGmtOffset)*3600);
   datetime dayEnd   = dayStart + (datetime)((InpDayEndHour   + InpGmtOffset)*3600);

   // --- A) Accumulation diapazoni ---
   double accHigh = -DBL_MAX, accLow = DBL_MAX;
   bool   accFound = false;
   for(int i=start; i<rates_total; i++)
   {
      if(time[i] >= accEnd) break;
      if(time[i] >= accStart)
      {
         if(high[i] > accHigh) accHigh = high[i];
         if(low[i]  < accLow)  accLow  = low[i];
         accFound = true;
      }
   }
   if(!accFound || accHigh <= accLow) return;
   double range = accHigh - accLow;

   if(InpShowAcc)
   {
      DrawRect("acc_"+(string)dayStart, accStart, accHigh, accEnd, accLow,
               InpAccColor, "Accumulation");
      if(InpShowLabels)
         DrawLabel("aL_"+(string)dayStart, accStart, accHigh, "A", InpAccColor, ANCHOR_LEFT_LOWER);
   }

   // --- M) Manipulation: accEnd dan keyin birinchi high/low sindirish ---
   datetime manipTime = 0;
   double   manipPrice = 0;
   int      manipSide = 0;     // +1 = yuqoriga sweep (bearish D), -1 = pastga sweep (bullish D)

   double   extHigh = accHigh, extLow = accLow;   // sweep ekstremumi
   for(int i=start; i<rates_total; i++)
   {
      if(time[i] < accEnd) continue;
      if(time[i] >= dayEnd) break;

      bool brokeUp   = (high[i] > accHigh);
      bool brokeDown = (low[i]  < accLow);

      if(manipSide == 0)
      {
         if(brokeUp && brokeDown)
         {
            // bir sham ikkalasini teginsa: close yo'nalishiga qaramnisbatan
            manipSide = (close[i] < open[i]) ? +1 : -1;
            manipTime = time[i];
         }
         else if(brokeUp)   { manipSide = +1; manipTime = time[i]; }
         else if(brokeDown) { manipSide = -1; manipTime = time[i]; }
      }

      // manipulyatsiya boshlangach ekstremumni kuzatamiz
      if(manipSide == +1 && high[i] > extHigh) { extHigh = high[i]; manipTime = time[i]; }
      if(manipSide == -1 && low[i]  < extLow)  { extLow  = low[i];  manipTime = time[i]; }
   }

   if(manipSide == 0) return;   // bu kun hali AMD ni yakunlamagan

   manipPrice = (manipSide == +1) ? extHigh : extLow;

   if(InpShowManip)
   {
      // sweep strelkasi (yuqoriga sweep -> pastga qaragan belgi, aksincha)
      DrawArrow("m_"+(string)dayStart, manipTime, manipPrice,
                (manipSide==+1)?234:233, InpManipColor, (manipSide==+1));
      if(InpShowLabels)
         DrawLabel("mL_"+(string)dayStart, manipTime, manipPrice, "M", InpManipColor,
                   (manipSide==+1)?ANCHOR_LOWER:ANCHOR_UPPER);
   }

   if(InpAlertOnManip)
      MaybeAlert(dayStart, manipSide);

   // --- D) Distribution: manipulyatsiyaga teskari harakat + target ---
   if(InpShowDist)
   {
      color dCol = (manipSide==+1) ? InpDistDownColor : InpDistUpColor;
      // yo'nalish chizig'i: manip ekstremumidan kun oxirigacha
      double target;
      if(manipSide == +1)
         target = accLow - range*InpTargetRatio;    // bearish distribution
      else
         target = accHigh + range*InpTargetRatio;   // bullish distribution

      DrawTrend("d_"+(string)dayStart, manipTime, manipPrice, dayEnd, target, dCol);
      if(InpShowLabels)
         DrawLabel("dL_"+(string)dayStart, dayEnd, target, "D", dCol,
                   (manipSide==+1)?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);

      if(InpShowTarget)
      {
         DrawHLine("t_"+(string)dayStart, manipTime, target, dayEnd, dCol, "AMD Target");
         if(InpShowLabels)
            DrawLabel("tL_"+(string)dayStart, dayEnd, target, "  Target", dCol, ANCHOR_LEFT);
      }
   }
}

//============================ DRAW HELPERS ===========================//

void DrawRect(string id, datetime t1, double p1, datetime t2, double p2,
              color clr, string tip)
{
   string name = gPrefix + id;
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

void DrawHLine(string id, datetime t1, double price, datetime t2, color clr, string tip)
{
   string name = gPrefix + id;
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

void DrawTrend(string id, datetime t1, double p1, datetime t2, double p2, color clr)
{
   string name = gPrefix + id;
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, "Distribution");
}

void DrawArrow(string id, datetime t, double price, int code, color clr, bool above)
{
   string name = gPrefix + id;
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, above?ANCHOR_BOTTOM:ANCHOR_TOP);
}

void DrawLabel(string id, datetime t, double price, string txt, color clr, int anchor)
{
   string name = gPrefix + id;
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString (0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
}

//+------------------------------------------------------------------+
//| Manipulation alerti (har kun uchun bir marta)                    |
//+------------------------------------------------------------------+
void MaybeAlert(datetime dayStart, int side)
{
   // faqat bugungi (eng so'nggi) kun uchun va bir marta
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);
   if(dayStart != today) return;

   static datetime lastAlertDay = 0;
   if(lastAlertDay == dayStart) return;
   lastAlertDay = dayStart;

   string dir = (side==+1) ? "Buy-side sweep -> Bearish distribution kutilmoqda"
                           : "Sell-side sweep -> Bullish distribution kutilmoqda";
   Alert(_Symbol, " ", EnumToString((ENUM_TIMEFRAMES)_Period), " AMD Manipulation: ", dir);
}
//+------------------------------------------------------------------+
