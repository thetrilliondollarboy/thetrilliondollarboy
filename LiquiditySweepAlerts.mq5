//+------------------------------------------------------------------+
//|                                        LiquiditySweepAlerts.mq5   |
//|   Key Liquidity Levels + one-shot voice/sound alert on sweep     |
//|                                                                  |
//|   Belgilaydigan likvidliklar:                                    |
//|     - Previous Day  High & Low                                   |
//|     - Previous Week  High & Low                                  |
//|     - Previous Month High & Low                                  |
//|     - Previous Session (Asia / London / New York) High & Low     |
//|     - 4H Candle High & Low                                       |
//|     - Swing Structure High & Low                                 |
//|     - Equal Highs / Equal Lows (EQH / EQL)                       |
//|                                                                  |
//|   Har bir daraja sweep qilinganda ATIGI 1 MARTA ovozli alert.    |
//|   Timeframe almashtirilganda alert QAYTA ishlamaydi: holat       |
//|   terminal GlobalVariable'larida saqlanadi.                      |
//+------------------------------------------------------------------+
#property copyright "Two Side Traders style - Liquidity Sweep Alerts"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//====================================================================
//  INPUTLAR
//====================================================================
input string  __GEN            = "======== UMUMIY ========";      // ---
input string  ObjPrefix        = "LSA_";                          // Obyekt prefiksi
input int     LineWidth        = 1;                               // Chiziq qalinligi
input ENUM_LINE_STYLE LineStyle= STYLE_SOLID;                     // Chiziq stili
input bool    ShowLabels       = true;                            // Yozuvlarni ko'rsatish
input int     LabelFontSize    = 8;                               // Yozuv o'lchami
input int     RightMarginBars  = 10;                             // Chiziqni o'ngga cho'zish (bar)

input string  __LVL            = "======== DARAJALAR (yoq/och) ========"; // ---
input bool    ShowPrevDay      = true;                            // Previous Day  H/L
input color   ColPrevDay       = clrTomato;                       // Previous Day rangi
input bool    ShowPrevWeek     = true;                            // Previous Week H/L
input color   ColPrevWeek      = clrOrangeRed;                    // Previous Week rangi
input bool    ShowPrevMonth    = true;                            // Previous Month H/L
input color   ColPrevMonth     = clrLimeGreen;                    // Previous Month rangi
input bool    ShowSessions     = true;                            // Previous Session H/L
input color   ColSession       = clrGray;                         // Session rangi
input bool    Show4H           = true;                            // 4H Candle H/L
input color   Col4H            = clrMediumPurple;                 // 4H rangi
input bool    ShowSwing        = true;                            // Swing Structure H/L
input color   ColSwing         = clrDodgerBlue;                   // Swing rangi
input bool    ShowEqual        = true;                            // Equal H/L (EQH/EQL)
input color   ColEqual         = clrGold;                         // Equal rangi

input string  __SESS           = "======== SESSIYALAR (server vaqti, soat) ========"; // ---
input bool    SessAsia         = true;                            // Osiyo sessiyasi
input int     AsiaStart        = 0;                               // Osiyo boshlanishi
input int     AsiaEnd          = 8;                               // Osiyo tugashi
input bool    SessLondon       = true;                            // London sessiyasi
input int     LondonStart      = 8;                               // London boshlanishi
input int     LondonEnd        = 16;                              // London tugashi
input bool    SessNY           = true;                            // New York sessiyasi
input int     NYStart          = 13;                              // NY boshlanishi
input int     NYEnd            = 21;                              // NY tugashi

input string  __SWG            = "======== SWING / EQUAL ========"; // ---
input int     SwingStrength    = 3;                               // Swing fraktal kuchi (o'ng/chap bar)
input int     SwingCount       = 2;                               // Nechta oxirgi swing (har tomon)
input int     LookbackBars     = 600;                             // Skaner chuqurligi (bar)
input double  EqualTolerancePts= 20;                             // Equal H/L tolerantligi (punkt)

input string  __ALR            = "======== ALERT ========";        // ---
input bool    EnableAlerts     = true;                            // Alertlarni yoqish
input bool    PlaySoundAlert   = true;                            // Ovozli signal
input string  SoundFile        = "alert2.wav";                   // Ovoz fayli
input bool    PopupAlert       = true;                            // Ekran alerti (Alert)
input bool    PushAlert        = false;                           // Telefonga push
input bool    EmailAlert       = false;                           // Email
input bool    SweepOnWick      = true;                            // true=fitil tegsa, false=yopilish kerak
input bool    AlertOnlyNew     = true;                            // Faqat yangi sweeplar (tarixiylar jim)

input string  __CLN            = "======== TOZALASH ========";     // ---
input int     StatePersistDays = 10;                              // Holatni necha kun saqlash

//====================================================================
//  ICHKI TUZILMALAR
//====================================================================
struct SLevel
  {
   string   id;        // TF'dan mustaqil unikal kalit (tur + anchor)
   string   label;     // ekrandagi yozuv
   double   price;     // daraja narxi
   bool     isHigh;    // true = yuqori likvidlik (yuqoriga sweep)
   datetime anchor;    // chizishni boshlash vaqti
   color    clr;       // rang
  };

SLevel   g_levels[];
datetime g_lastBar = 0;
bool     g_firstPass = true;
int      g_digits;
double   g_point;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_lastBar = 0;
   g_firstPass = true;
   ArrayResize(g_levels, 0);
   CleanupOldState();
   IndicatorSetString(INDICATOR_SHORTNAME, "Liquidity Sweep Alerts");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // TF almashganda (REASON_CHRCHANGE / REASON_PARAMETERS) faqat chizmalarni
   // olib tashlaymiz. GlobalVariable holati DAXLSIZ qoladi -> alert qayta chiqmaydi.
   ObjectsDeleteAll(0, ObjPrefix);
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

   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);

   // Yangi bar (yoki init) => darajalarni qayta hisoblab, chizamiz
   if(curBar != g_lastBar)
     {
      g_lastBar = curBar;
      BuildLevels();
      DrawLevels();
     }

   // Sweeplarni har tik tekshiramiz
   CheckSweeps();

   g_firstPass = false;
   return(rates_total);
  }

//====================================================================
//  DARAJALARNI YIG'ISH
//====================================================================
void AddLevel(string id, string label, double price, bool isHigh, datetime anchor, color clr)
  {
   if(price <= 0)
      return;
   int n = ArraySize(g_levels);
   ArrayResize(g_levels, n + 1);
   g_levels[n].id     = id;
   g_levels[n].label  = label;
   g_levels[n].price  = NormalizeDouble(price, g_digits);
   g_levels[n].isHigh = isHigh;
   g_levels[n].anchor = anchor;
   g_levels[n].clr    = clr;
  }
//+------------------------------------------------------------------+
void BuildLevels()
  {
   ArrayResize(g_levels, 0);

   //--- Previous Day / Week / Month
   AddTFLevel(ShowPrevDay,   PERIOD_D1,  "PDH", "PDL", "Prev Day",   ColPrevDay);
   AddTFLevel(ShowPrevWeek,  PERIOD_W1,  "PWH", "PWL", "Prev Week",  ColPrevWeek);
   AddTFLevel(ShowPrevMonth, PERIOD_MN1, "PMH", "PML", "Prev Month", ColPrevMonth);

   //--- Previous 4H candle
   if(Show4H)
      AddTFLevel(true, PERIOD_H4, "4HH", "4HL", "4H", Col4H, false);

   //--- Sessiyalar
   if(ShowSessions)
     {
      if(SessAsia)   AddSessionLevel(AsiaStart,   AsiaEnd,   "Asia");
      if(SessLondon) AddSessionLevel(LondonStart, LondonEnd, "London");
      if(SessNY)     AddSessionLevel(NYStart,     NYEnd,     "NY");
     }

   //--- Swing structure + Equal H/L
   if(ShowSwing || ShowEqual)
      BuildSwingAndEqual();
  }
//+------------------------------------------------------------------+
//| Oldingi yopilgan TF svechasining H/L darajasi                    |
//| extendPrev=true bo'lsa anchor oldingi bar boshiga, aks holda     |
//| joriy davr boshiga qo'yiladi.                                    |
//+------------------------------------------------------------------+
void AddTFLevel(bool show, ENUM_TIMEFRAMES tf, string hid, string lid,
                string name, color clr, bool useDateInId = true)
  {
   if(!show)
      return;
   double hi = iHigh(_Symbol, tf, 1);
   double lo = iLow(_Symbol, tf, 1);
   datetime bt = iTime(_Symbol, tf, 1);
   if(hi <= 0 || lo <= 0 || bt == 0)
      return;

   string stamp = useDateInId ? TimeToString(bt, TIME_DATE)
                              : TimeToString(bt, TIME_DATE|TIME_MINUTES);
   AddLevel(hid + "|" + stamp, name + " High", hi, true,  bt, clr);
   AddLevel(lid + "|" + stamp, name + " Low",  lo, false, bt, clr);
  }
//+------------------------------------------------------------------+
//| Oxirgi tugagan sessiya oynasidagi High/Low                       |
//+------------------------------------------------------------------+
void AddSessionLevel(int startHour, int endHour, string name)
  {
   datetime sStart, sEnd;
   if(!LastSessionWindow(startHour, endHour, sStart, sEnd))
      return;

   double hi, lo;
   if(!RangeHighLow(sStart, sEnd, hi, lo))
      return;

   string stamp = TimeToString(sStart, TIME_DATE|TIME_MINUTES);
   AddLevel("SES_" + name + "_H|" + stamp, name + " High", hi, true,  sStart, ColSession);
   AddLevel("SES_" + name + "_L|" + stamp, name + " Low",  lo, false, sStart, ColSession);
  }
//+------------------------------------------------------------------+
//| Hozirgi vaqtdan oldingi ENG oxirgi tugagan sessiya oynasi        |
//+------------------------------------------------------------------+
bool LastSessionWindow(int startHour, int endHour, datetime &outStart, datetime &outEnd)
  {
   datetime now = TimeCurrent();
   int dur = ((endHour - startHour) % 24 + 24) % 24;   // soatlarda
   if(dur == 0) dur = 24;

   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime todayMidnight = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);

   datetime best = 0, bestEnd = 0;
   for(int d = 0; d <= 3; d++)
     {
      datetime s = todayMidnight - d * 86400 + (datetime)startHour * 3600;
      datetime e = s + (datetime)dur * 3600;
      if(e <= now && e > bestEnd)
        {
         bestEnd = e;
         best    = s;
        }
     }
   if(best == 0)
      return(false);
   outStart = best;
   outEnd   = bestEnd;
   return(true);
  }
//+------------------------------------------------------------------+
//| Vaqt oralig'idagi High/Low (M15 asosida)                         |
//+------------------------------------------------------------------+
bool RangeHighLow(datetime from, datetime to, double &hi, double &lo)
  {
   MqlRates r[];
   int copied = CopyRates(_Symbol, PERIOD_M15, from, to, r);
   if(copied <= 0)
     {
      // zaxira: joriy TF
      copied = CopyRates(_Symbol, _Period, from, to, r);
      if(copied <= 0)
         return(false);
     }
   hi = -DBL_MAX; lo = DBL_MAX;
   for(int i = 0; i < copied; i++)
     {
      if(r[i].high > hi) hi = r[i].high;
      if(r[i].low  < lo) lo = r[i].low;
     }
   return(hi > 0 && lo < DBL_MAX);
  }
//+------------------------------------------------------------------+
//| Swing highs/lows + Equal Highs/Lows                              |
//+------------------------------------------------------------------+
void BuildSwingAndEqual()
  {
   int need = MathMin(LookbackBars, Bars(_Symbol, _Period) - 1);
   if(need < (SwingStrength * 2 + 2))
      return;

   double H[], L[];
   datetime T[];
   ArraySetAsSeries(H, true);
   ArraySetAsSeries(L, true);
   ArraySetAsSeries(T, true);
   if(CopyHigh(_Symbol, _Period, 0, need, H) <= 0) return;
   if(CopyLow(_Symbol, _Period, 0, need, L)  <= 0) return;
   if(CopyTime(_Symbol, _Period, 0, need, T) <= 0) return;

   int s = SwingStrength;

   // swing highs/lows to'plash (yaqindan uzoqqa)
   double  shPrice[]; datetime shTime[];
   double  slPrice[]; datetime slTime[];
   int shN = 0, slN = 0;

   for(int i = s; i < need - s; i++)
     {
      // Swing High
      bool isHigh = true;
      for(int k = 1; k <= s; k++)
         if(H[i] < H[i-k] || H[i] < H[i+k]) { isHigh = false; break; }
      if(isHigh)
        {
         int n = ArraySize(shPrice);
         ArrayResize(shPrice, n+1); ArrayResize(shTime, n+1);
         shPrice[n] = H[i]; shTime[n] = T[i]; shN++;
        }
      // Swing Low
      bool isLow = true;
      for(int k = 1; k <= s; k++)
         if(L[i] > L[i-k] || L[i] > L[i+k]) { isLow = false; break; }
      if(isLow)
        {
         int n = ArraySize(slPrice);
         ArrayResize(slPrice, n+1); ArrayResize(slTime, n+1);
         slPrice[n] = L[i]; slTime[n] = T[i]; slN++;
        }
     }

   //--- Swing Structure: oxirgi N ta swing (har tomon)
   if(ShowSwing)
     {
      int cnt = MathMin(SwingCount, shN);
      for(int i = 0; i < cnt; i++)
        {
         string stamp = TimeToString(shTime[i], TIME_DATE|TIME_MINUTES);
         AddLevel("SWH|" + stamp, "Swing High", shPrice[i], true, shTime[i], ColSwing);
        }
      cnt = MathMin(SwingCount, slN);
      for(int i = 0; i < cnt; i++)
        {
         string stamp = TimeToString(slTime[i], TIME_DATE|TIME_MINUTES);
         AddLevel("SWL|" + stamp, "Swing Low", slPrice[i], false, slTime[i], ColSwing);
        }
     }

   //--- Equal Highs / Lows: tolerantlik ichidagi juftliklar
   if(ShowEqual)
     {
      double tol = EqualTolerancePts * g_point;
      FindEqual(shPrice, shTime, shN, tol, true,  "EQH", "Equal High");
      FindEqual(slPrice, slTime, slN, tol, false, "EQL", "Equal Low");
     }
  }
//+------------------------------------------------------------------+
//| Tolerantlik ichida yaqin ikki swingni topib Equal daraja qo'shish|
//+------------------------------------------------------------------+
void FindEqual(double &p[], datetime &t[], int n, double tol, bool isHigh,
               string idpfx, string name)
  {
   // yaqindan boshlab: birinchi topilgan juftlik = eng dolzarb equal
   for(int i = 0; i < n; i++)
      for(int j = i + 1; j < n; j++)
        {
         if(MathAbs(p[i] - p[j]) <= tol)
           {
            double lvl = (p[i] + p[j]) / 2.0;
            datetime anch = (t[i] < t[j]) ? t[i] : t[j];
            string stamp = TimeToString(anch, TIME_DATE|TIME_MINUTES);
            AddLevel(idpfx + "|" + stamp, name, lvl, isHigh, anch, ColEqual);
            return;   // faqat eng oxirgi equal klaster
           }
        }
  }

//====================================================================
//  CHIZISH
//====================================================================
void DrawLevels()
  {
   ObjectsDeleteAll(0, ObjPrefix);
   datetime rightEdge = TimeCurrent() + (datetime)RightMarginBars * PeriodSeconds(_Period);

   for(int i = 0; i < ArraySize(g_levels); i++)
     {
      string ln = ObjPrefix + "L_" + g_levels[i].id;
      if(ObjectCreate(0, ln, OBJ_TREND, 0, g_levels[i].anchor, g_levels[i].price,
                      rightEdge, g_levels[i].price))
        {
         ObjectSetInteger(0, ln, OBJPROP_COLOR, g_levels[i].clr);
         ObjectSetInteger(0, ln, OBJPROP_STYLE, LineStyle);
         ObjectSetInteger(0, ln, OBJPROP_WIDTH, LineWidth);
         ObjectSetInteger(0, ln, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, ln, OBJPROP_BACK, true);
         ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
        }

      if(ShowLabels)
        {
         string tx = ObjPrefix + "T_" + g_levels[i].id;
         if(ObjectCreate(0, tx, OBJ_TEXT, 0, rightEdge, g_levels[i].price))
           {
            ObjectSetString(0, tx, OBJPROP_TEXT, " " + g_levels[i].label);
            ObjectSetInteger(0, tx, OBJPROP_COLOR, g_levels[i].clr);
            ObjectSetInteger(0, tx, OBJPROP_FONTSIZE, LabelFontSize);
            ObjectSetInteger(0, tx, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, tx, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, tx, OBJPROP_HIDDEN, true);
           }
        }
     }
  }

//====================================================================
//  SWEEP TEKSHIRISH + BIR MARTALIK ALERT
//====================================================================
void CheckSweeps()
  {
   double curHigh = iHigh(_Symbol, _Period, 0);
   double curLow  = iLow(_Symbol, _Period, 0);
   double prevHigh= iHigh(_Symbol, _Period, 1);
   double prevLow = iLow(_Symbol, _Period, 1);
   double prevClose = iClose(_Symbol, _Period, 1);
   if(curHigh <= 0 || curLow <= 0)
      return;

   for(int i = 0; i < ArraySize(g_levels); i++)
     {
      string key = StateKey(g_levels[i]);
      bool already = GlobalVariableCheck(key);

      bool swept = false;
      if(g_levels[i].isHigh)
        {
         if(SweepOnWick)
            swept = (curHigh > g_levels[i].price) || (prevHigh > g_levels[i].price);
         else
            swept = (prevClose > g_levels[i].price);   // yopilish bilan
        }
      else
        {
         if(SweepOnWick)
            swept = (curLow < g_levels[i].price) || (prevLow < g_levels[i].price);
         else
            swept = (prevClose < g_levels[i].price);
        }

      if(!swept)
         continue;

      if(already)
         continue;   // bu daraja allaqachon signal bergan -> qayta emas

      // Birinchi hisob (yoki AlertOnlyNew): tarixiy sweeplarni JIM belgilaymiz
      if(g_firstPass && AlertOnlyNew)
        {
         GlobalVariableSet(key, (double)TimeCurrent());
         continue;
        }

      // Yangi sweep -> 1 marta alert + holatni yozib qo'yamiz
      GlobalVariableSet(key, (double)TimeCurrent());
      FireAlert(g_levels[i]);
     }
  }
//+------------------------------------------------------------------+
string StateKey(const SLevel &lv)
  {
   // Symbol + daraja id + narx => TF'dan mustaqil, takrorlanmas kalit.
   return(ObjPrefix + _Symbol + "|" + lv.id + "|" +
          DoubleToString(lv.price, g_digits));
  }
//+------------------------------------------------------------------+
void FireAlert(const SLevel &lv)
  {
   if(!EnableAlerts)
      return;
   string dir = lv.isHigh ? "yuqoriga (buy-side)" : "pastga (sell-side)";
   string msg = StringFormat("%s %s: %s SWEEP %s @ %s",
                             _Symbol, EnumToString(_Period),
                             lv.label, dir,
                             DoubleToString(lv.price, g_digits));

   if(PopupAlert)   Alert(msg);
   if(PlaySoundAlert) PlaySound(SoundFile);
   if(PushAlert)    SendNotification(msg);
   if(EmailAlert)   SendMail("Liquidity Sweep", msg);
   Print("[LSA] ", msg);
  }

//====================================================================
//  ESKI HOLATNI TOZALASH (global o'zgaruvchilar to'planib qolmasin)
//====================================================================
void CleanupOldState()
  {
   int total = GlobalVariablesTotal();
   datetime limit = TimeCurrent() - (datetime)StatePersistDays * 86400;
   for(int i = total - 1; i >= 0; i--)
     {
      string nm = GlobalVariableName(i);
      if(StringFind(nm, ObjPrefix) != 0)
         continue;
      datetime t = GlobalVariableTime(nm);
      if(t > 0 && t < limit)
         GlobalVariableDel(nm);
     }
  }
//+------------------------------------------------------------------+
