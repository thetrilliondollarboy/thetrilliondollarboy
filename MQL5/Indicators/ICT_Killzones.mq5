//+------------------------------------------------------------------+
//|                                               ICT_Killzones.mq5   |
//|            ICT Killzones Toolkit (LuxAlgo uslubidagi to'liq klon) |
//|                                                                  |
//|  TradingView'dagi "LuxAlgo - ICT Killzones Toolkit" indikatori   |
//|  konsepsiyasining MetaTrader 5 uchun to'liq, mustaqil qayta-     |
//|  yozilgan versiyasi. Barcha sozlamalar/izohlar o'zbek tilida.    |
//|                                                                  |
//|  BO'LIMLAR:                                                       |
//|   1) KILLZONES  - Asian / London / New York / New York PM        |
//|   2) ORDER BLOCKS & BREAKER BLOCKS                                |
//|   3) MARKET STRUCTURE SHIFTS (MSS)                                |
//|   4) FAIR VALUE GAPS (FVG)                                        |
//|                                                                  |
//|  ESLATMA: Bu — ochiq, mustaqil implementatsiya. LuxAlgo'ning     |
//|  yopiq (proprietary) Pine Script kodining nusxasi EMAS; xuddi    |
//|  shu funksionallik noldan MQL5 da yozilgan.                      |
//+------------------------------------------------------------------+
#property copyright   "ICT Killzones Toolkit - MT5 ochiq implementatsiya"
#property link        ""
#property version     "2.00"
#property description "ICT Killzones Toolkit: Killzones + Order/Breaker Blocks + MSS + FVG"
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//+------------------------------------------------------------------+
//| Sanab o'tilgan turlar (enum)                                     |
//+------------------------------------------------------------------+
enum ENUM_DISPLAY_MODE
  {
   DISP_FIRST = 0,   // Birinchisi (har sessiyada faqat 1-tasi)
   DISP_ALL   = 1,   // Barchasi
   DISP_OFF   = 2    // O'chirilgan
  };

enum ENUM_MITIGATION
  {
   MIT_CLOSE = 0,    // Yopilish narxi (Close)
   MIT_WICK  = 1     // Soya (Wick / High-Low)
  };

enum ENUM_OPEN_PRICE
  {
   OPEN_NONE  = 0,   // Yo'q
   OPEN_DAY   = 1,   // Kunlik ochilish
   OPEN_WEEK  = 2,   // Haftalik ochilish
   OPEN_MONTH = 3    // Oylik ochilish
  };

//+------------------------------------------------------------------+
//| INPUT — Umumiy                                                    |
//+------------------------------------------------------------------+
input group "════════ UMUMIY ════════"
input int  InpTimezoneOffset = 0;    // Broker vaqti ofseti (soat, killzone vaqtiga qo'shiladi)
input int  InpDaysToShow     = 15;   // Tarix: ko'rsatiladigan kunlar soni
input int  InpMaxTFMinutes   = 30;   // Killzone'lar shu daqiqagacha bo'lgan TF larda ko'rinadi
input bool InpBackgroundFill = true; // Killzone fonini bo'yash (yarim shaffof)

//+------------------------------------------------------------------+
//| INPUT — Killzones                                                 |
//+------------------------------------------------------------------+
input group "════════ KILLZONES ════════"
input bool   InpKZ_LinesTB    = true;         // Killzone chiziqlari: Tepa/Past (Top/Bottom)
input bool   InpKZ_Mean       = false;        // O'rta chiziq (Mean / 50%)
input bool   InpKZ_ExtendTB   = true;         // Tepa/Past chiziqlarni o'ngga cho'zish
input bool   InpKZ_Labels     = true;         // Killzone nom yorliqlari (Labels)

input group "──── Asian ────"
input bool   InpAS_On     = true;             // Asian — yoqilgan
input string InpAS_Name    = "Asian";         // Nomi
input string InpAS_Start   = "19:00";         // Boshlanish (SS:DD)
input string InpAS_End      = "23:05";        // Tugash (SS:DD)
input color  InpAS_Color   = C'80,30,40';     // Rangi

input group "──── London ────"
input bool   InpLO_On     = true;             // London — yoqilgan
input string InpLO_Name    = "London";        // Nomi
input string InpLO_Start   = "01:00";         // Boshlanish (SS:DD)
input string InpLO_End      = "04:05";        // Tugash (SS:DD)
input color  InpLO_Color   = C'30,40,90';     // Rangi

input group "──── New York ────"
input bool   InpNY_On     = true;             // New York — yoqilgan
input string InpNY_Name    = "New York";      // Nomi
input string InpNY_Start   = "06:00";         // Boshlanish (SS:DD)
input string InpNY_End      = "09:05";        // Tugash (SS:DD)
input color  InpNY_Color   = C'60,60,60';     // Rangi

input group "──── New York PM ────"
input bool   InpNP_On     = true;             // New York PM — yoqilgan
input string InpNP_Name    = "New York PM";   // Nomi
input string InpNP_Start   = "13:30";         // Boshlanish (SS:DD)
input string InpNP_End      = "16:00";        // Tugash (SS:DD)
input color  InpNP_Color   = C'20,30,70';     // Rangi

input group "──── Killzone qo'shimcha ────"
input ENUM_OPEN_PRICE InpOpenPriceOf = OPEN_NONE; // Ochilish narxi: qaysi davr
input bool            InpOpenSep      = true;      // Ajratgich (Separator) vertikal chiziq
input color           InpOpenColor    = clrGray;   // Ochilish/ajratgich rangi
input bool            InpOpenLabel    = true;      // Ochilish narxi yorlig'i

//+------------------------------------------------------------------+
//| INPUT — Order Blocks & Breaker Blocks                            |
//+------------------------------------------------------------------+
input group "════════ ORDER & BREAKER BLOCKS ════════"
input bool            InpOB_On        = true;       // Order Blocks | Breaker Blocks — yoqilgan
input int             InpOB_Swing     = 5;          // Swing aniqlash uzunligi
input ENUM_MITIGATION InpOB_Mitigation= MIT_CLOSE;  // Mitigatsiya narxi
input bool            InpOB_UseBody   = false;      // Aniqlashda shamning tanasidan foydalanish
input bool            InpOB_Remove    = true;       // Mitigatsiya qilingan bloklarni o'chirish
input bool            InpOB_Extend    = true;       // Bloklarni o'ngga cho'zish
input ENUM_DISPLAY_MODE InpOB_Display = DISP_FIRST; // Ko'rsatish rejimi
input color           InpOB_BullOB    = C'20,60,120';  // Order Block — Bullish
input color           InpOB_BearOB    = C'120,40,20';  // Order Block — Bearish
input color           InpOB_BullBB    = C'80,20,20';    // Breaker Block — Bullish
input color           InpOB_BearBB    = C'20,80,30';    // Breaker Block — Bearish
input bool            InpOB_Text      = true;       // Blok matnini ko'rsatish

//+------------------------------------------------------------------+
//| INPUT — Market Structure Shifts                                  |
//+------------------------------------------------------------------+
input group "════════ MARKET STRUCTURE SHIFTS ════════"
input bool            InpMSS_On       = true;       // Market Structure Shifts — yoqilgan
input int             InpMSS_Length   = 7;          // Aniqlash uzunligi (Detection Length)
input ENUM_DISPLAY_MODE InpMSS_Display= DISP_FIRST; // Ko'rsatish rejimi
input color           InpMSS_Bull     = C'46,139,120'; // Bullish rangi
input color           InpMSS_Bear     = C'230,90,80';  // Bearish rangi
input bool            InpMSS_Text     = true;       // MSS matnini ko'rsatish

//+------------------------------------------------------------------+
//| INPUT — Fair Value Gaps                                          |
//+------------------------------------------------------------------+
input group "════════ FAIR VALUE GAPS ════════"
input bool   InpFVG_On       = true;               // Fair Value Gaps — yoqilgan
input double InpFVG_Filter   = 1.2;                // FVG kengligi filtri (o'rtachaga nisbatan)
input bool   InpFVG_Remove   = true;               // Mitigatsiya qilinganlarini o'chirish
input bool   InpFVG_Extend   = true;               // FVG larni o'ngga cho'zish
input ENUM_DISPLAY_MODE InpFVG_Display = DISP_FIRST;// Ko'rsatish rejimi
input color  InpFVG_Bull     = C'20,70,40';        // Bullish imbalans rangi
input color  InpFVG_Bear     = C'70,25,25';        // Bearish imbalans rangi
input bool   InpFVG_Text     = true;               // FVG matnini ko'rsatish

//+------------------------------------------------------------------+
//| INPUT — Dashboard (Jadval)                                       |
//+------------------------------------------------------------------+
input group "════════ DASHBOARD ════════"
input bool             InpDashOn    = true;                 // Jadvalni ko'rsatish
input ENUM_BASE_CORNER InpDashCorner= CORNER_RIGHT_UPPER;   // Joylashuv burchagi
input int              InpDashX      = 10;                  // X ofset (px)
input int              InpDashY      = 20;                  // Y ofset (px)
input color            InpDashText   = clrWhite;            // Matn rangi
input color            InpDashBg     = C'25,25,25';         // Fon rangi

//+------------------------------------------------------------------+
//| Konstantalar                                                     |
//+------------------------------------------------------------------+
#define KZ_COUNT   4
#define OBJ_PREFIX "ICTKZ_"

//+------------------------------------------------------------------+
//| Killzone ta'rifi                                                 |
//+------------------------------------------------------------------+
struct KillzoneDef
  {
   bool   enabled;
   string name;
   int    startSec;
   int    endSec;
   color  clr;
  };
KillzoneDef Zones[KZ_COUNT];

//+------------------------------------------------------------------+
//| Yordamchi: "SS:DD" ni yarim tundan boshlab sekundlarga           |
//+------------------------------------------------------------------+
int ParseTimeToSec(const string t)
  {
   string parts[];
   int n = StringSplit(t, ':', parts);
   int hh = 0, mm = 0;
   if(n >= 1) hh = (int)StringToInteger(parts[0]);
   if(n >= 2) mm = (int)StringToInteger(parts[1]);
   hh = (hh % 24 + 24) % 24;
   mm = (mm % 60 + 60) % 60;
   return hh * 3600 + mm * 60;
  }

//+------------------------------------------------------------------+
//| Yordamchi: berilgan vaqt uchun kun ichidagi sekundlar            |
//+------------------------------------------------------------------+
int SecondsOfDay(const datetime t)
  {
   datetime shifted = t + (datetime)(InpTimezoneOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(shifted, dt);
   return dt.hour * 3600 + dt.min * 60 + dt.sec;
  }

//+------------------------------------------------------------------+
//| Yordamchi: t kuni boshini (yarim tun, ofset bilan) qaytaradi     |
//+------------------------------------------------------------------+
datetime DayStart(const datetime t)
  {
   datetime shifted = t + (datetime)(InpTimezoneOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(shifted, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime midnightShifted = StructToTime(dt);
   return midnightShifted - (datetime)(InpTimezoneOffset * 3600);
  }

//+------------------------------------------------------------------+
//| Yordamchi: kun ichidagi sekund killzone oynasida-mi              |
//+------------------------------------------------------------------+
bool InWindow(const int sec, const int startSec, const int endSec)
  {
   if(startSec == endSec)
      return false;
   if(startSec < endSec)
      return (sec >= startSec && sec < endSec);
   return (sec >= startSec || sec < endSec);   // yarim tunni kesib o'tsa
  }

//+------------------------------------------------------------------+
//| Yordamchi: bar qaysi killzone'ga tegishli (-1 = hech biriga)     |
//+------------------------------------------------------------------+
int ZoneOfBar(const datetime t)
  {
   int sec = SecondsOfDay(t);
   for(int z = 0; z < KZ_COUNT; z++)
      if(Zones[z].enabled && InWindow(sec, Zones[z].startSec, Zones[z].endSec))
         return z;
   return -1;
  }

//+------------------------------------------------------------------+
//| Ishga tushirish                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   Zones[0].enabled=InpAS_On; Zones[0].name=InpAS_Name;
   Zones[0].startSec=ParseTimeToSec(InpAS_Start); Zones[0].endSec=ParseTimeToSec(InpAS_End);
   Zones[0].clr=InpAS_Color;

   Zones[1].enabled=InpLO_On; Zones[1].name=InpLO_Name;
   Zones[1].startSec=ParseTimeToSec(InpLO_Start); Zones[1].endSec=ParseTimeToSec(InpLO_End);
   Zones[1].clr=InpLO_Color;

   Zones[2].enabled=InpNY_On; Zones[2].name=InpNY_Name;
   Zones[2].startSec=ParseTimeToSec(InpNY_Start); Zones[2].endSec=ParseTimeToSec(InpNY_End);
   Zones[2].clr=InpNY_Color;

   Zones[3].enabled=InpNP_On; Zones[3].name=InpNP_Name;
   Zones[3].startSec=ParseTimeToSec(InpNP_Start); Zones[3].endSec=ParseTimeToSec(InpNP_End);
   Zones[3].clr=InpNP_Color;

   IndicatorSetString(INDICATOR_SHORTNAME, "ICT Killzones Toolkit");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Yakunlash                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Obyekt yaratish yordamchilari                                    |
//+------------------------------------------------------------------+
void SetRectangle(const string name, datetime t1, double p1, datetime t2, double p2,
                  color clr, bool fill, int width, ENUM_LINE_STYLE style=STYLE_SOLID)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   else { ObjectMove(0,name,0,t1,p1); ObjectMove(0,name,1,t2,p2); }
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_FILL,fill);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void SetTrend(const string name, datetime t1, double p1, datetime t2, double p2,
              color clr, ENUM_LINE_STYLE style, int width, bool ray)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   else { ObjectMove(0,name,0,t1,p1); ObjectMove(0,name,1,t2,p2); }
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,ray);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void SetText(const string name, datetime t, double p, const string txt, color clr,
             ENUM_ANCHOR_POINT anchor, int fontsize=8)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   else ObjectMove(0,name,0,t,p);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
//| Bufer-massivlar (rebuild davomida to'ldiriladi)                  |
//+------------------------------------------------------------------+
// Killzone sessiya ma'lumotlari
struct SessionInfo { datetime t1; datetime t2; double hi; double lo; int zone; };

//+------------------------------------------------------------------+
//| Asosiy hisoblash                                                 |
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
   if(rates_total < 30)
      return(rates_total);

   ArraySetAsSeries(time,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);

   // Faqat yangi bar paydo bo'lganda to'liq qayta chizamiz (CPU tejash).
   static int lastRates = 0;
   bool newBar = (rates_total != lastRates);
   if(!newBar && prev_calculated > 0)
      return(rates_total);
   lastRates = rates_total;

   ObjectsDeleteAll(0, OBJ_PREFIX);

   // Timeframe filtri: faqat InpMaxTFMinutes gacha ko'rsatiladi.
   int tfMin = PeriodSeconds() / 60;
   if(tfMin > InpMaxTFMinutes && InpMaxTFMinutes > 0)
     {
      ChartRedraw(0);
      return(rates_total);   // bu TF da killzone'lar ko'rsatilmaydi
     }

   // Ko'rsatiladigan diapazon boshini topamiz.
   datetime cutoff = time[rates_total-1] - (datetime)((long)InpDaysToShow*86400);
   int startIdx = 0;
   for(int i=rates_total-1; i>=0; i--)
      if(time[i] < cutoff) { startIdx = i+1; break; }
   if(startIdx < 0) startIdx = 0;
   if(startIdx > rates_total-1) startIdx = 0;

   datetime rightEdge = time[rates_total-1] + (datetime)(PeriodSeconds()*30);

   // 1) KILLZONES ------------------------------------------------------
   BuildKillzones(rates_total, startIdx, rightEdge, time, high, low);

   // 2) OPEN PRICE lines ----------------------------------------------
   if(InpOpenPriceOf != OPEN_NONE)
      BuildOpenPrices(rates_total, startIdx, rightEdge, time, open);

   // 3) FAIR VALUE GAPS -----------------------------------------------
   if(InpFVG_On && InpFVG_Display != DISP_OFF)
      BuildFVG(rates_total, startIdx, rightEdge, time, high, low, close);

   // 4) ORDER / BREAKER BLOCKS ----------------------------------------
   if(InpOB_On && InpOB_Display != DISP_OFF)
      BuildOrderBlocks(rates_total, startIdx, rightEdge, time, open, high, low, close);

   // 5) MARKET STRUCTURE SHIFTS ---------------------------------------
   if(InpMSS_On && InpMSS_Display != DISP_OFF)
      BuildMSS(rates_total, startIdx, time, high, low, close);

   // 6) DASHBOARD ------------------------------------------------------
   if(InpDashOn)
      UpdateDashboard();

   ChartRedraw(0);
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 1) KILLZONES qurish                                              |
//+------------------------------------------------------------------+
void BuildKillzones(const int rates_total, const int startIdx, const datetime rightEdge,
                    const datetime &time[], const double &high[], const double &low[])
  {
   datetime sKey[KZ_COUNT], sT1[KZ_COUNT];
   double   sHi[KZ_COUNT], sLo[KZ_COUNT];
   int      sCnt[KZ_COUNT], sIdx1[KZ_COUNT];
   bool     sAct[KZ_COUNT];
   for(int z=0;z<KZ_COUNT;z++){ sKey[z]=0; sT1[z]=0; sHi[z]=-DBL_MAX; sLo[z]=DBL_MAX; sCnt[z]=0; sAct[z]=false; sIdx1[z]=0; }

   for(int i=startIdx; i<rates_total; i++)
     {
      int sec = SecondsOfDay(time[i]);
      for(int z=0; z<KZ_COUNT; z++)
        {
         if(!Zones[z].enabled) continue;
         bool inside = InWindow(sec, Zones[z].startSec, Zones[z].endSec);
         if(inside)
           {
            datetime key = DayStart(time[i]);
            if(sAct[z] && Zones[z].startSec > Zones[z].endSec) key = sKey[z];
            if(!sAct[z] || key != sKey[z])
              {
               sAct[z]=true; sKey[z]=DayStart(time[i]); sT1[z]=time[i];
               sHi[z]=high[i]; sLo[z]=low[i]; sIdx1[z]=i; sCnt[z]++;
              }
            else
              {
               if(high[i]>sHi[z]) sHi[z]=high[i];
               if(low[i] <sLo[z]) sLo[z]=low[i];
              }
            DrawOneKillzone(z, sCnt[z], sT1[z], time[i], sHi[z], sLo[z], rightEdge);
           }
         else if(sAct[z])
           {
            sAct[z]=false;
            DrawOneKillzone(z, sCnt[z], sT1[z], time[i>0?i-1:i], sHi[z], sLo[z], rightEdge);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Bitta killzone sessiyasini chizish                              |
//+------------------------------------------------------------------+
void DrawOneKillzone(const int z, const int idx, datetime t1, datetime t2,
                     double hi, double lo, const datetime rightEdge)
  {
   string base = StringFormat("%sKZ_%d_%d_", OBJ_PREFIX, z, idx);
   color c = Zones[z].clr;

   // Fon (rectangle)
   SetRectangle(base+"box", t1, hi, t2, lo, c, InpBackgroundFill, 1);

   // Tepa/Past chiziqlari
   if(InpKZ_LinesTB)
     {
      datetime end = InpKZ_ExtendTB ? rightEdge : t2;
      SetTrend(base+"top", t1, hi, end, hi, c, STYLE_SOLID, 1, false);
      SetTrend(base+"bot", t1, lo, end, lo, c, STYLE_SOLID, 1, false);
     }
   // O'rta chiziq
   if(InpKZ_Mean)
     {
      double m=(hi+lo)/2.0;
      datetime end = InpKZ_ExtendTB ? rightEdge : t2;
      SetTrend(base+"mean", t1, m, end, m, c, STYLE_DOT, 1, false);
     }
   // Yorliq
   if(InpKZ_Labels)
      SetText(base+"lbl", t1, hi, "  "+Zones[z].name, c, ANCHOR_LEFT_LOWER, 8);
  }

//+------------------------------------------------------------------+
//| 2) OPEN PRICE (Day/Week/Month) chiziqlari                        |
//+------------------------------------------------------------------+
void BuildOpenPrices(const int rates_total, const int startIdx, const datetime rightEdge,
                     const datetime &time[], const double &open[])
  {
   int cnt=0;
   for(int i=MathMax(startIdx,1); i<rates_total; i++)
     {
      if(!IsNewPeriod(time[i-1], time[i], InpOpenPriceOf)) continue;
      double op = open[i];
      string base = StringFormat("%sOP_%d_", OBJ_PREFIX, cnt++);
      // gorizontal ochilish chizig'i
      SetTrend(base+"ln", time[i], op, rightEdge, op, InpOpenColor, STYLE_DASHDOT, 1, false);
      // ajratgich (vertikal)
      if(InpOpenSep)
        {
         string vn = base+"sep";
         if(ObjectFind(0,vn)<0) ObjectCreate(0,vn,OBJ_VLINE,0,time[i],0);
         else ObjectMove(0,vn,0,time[i],0);
         ObjectSetInteger(0,vn,OBJPROP_COLOR,InpOpenColor);
         ObjectSetInteger(0,vn,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,vn,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,vn,OBJPROP_BACK,true);
         ObjectSetInteger(0,vn,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,vn,OBJPROP_HIDDEN,true);
        }
      if(InpOpenLabel)
        {
         string tag = (InpOpenPriceOf==OPEN_DAY)?"K.O":(InpOpenPriceOf==OPEN_WEEK)?"H.O":"O.O";
         SetText(base+"lbl", time[i], op, tag+" ", InpOpenColor, ANCHOR_RIGHT_LOWER, 8);
        }
     }
  }

//+------------------------------------------------------------------+
//| Yangi davr (kun/hafta/oy) boshlanishini aniqlash                |
//+------------------------------------------------------------------+
bool IsNewPeriod(const datetime prev, const datetime cur, const ENUM_OPEN_PRICE mode)
  {
   MqlDateTime p, c;
   TimeToStruct(prev + (datetime)(InpTimezoneOffset*3600), p);
   TimeToStruct(cur  + (datetime)(InpTimezoneOffset*3600), c);
   if(mode==OPEN_DAY)   return (p.day != c.day || p.mon != c.mon || p.year != c.year);
   if(mode==OPEN_WEEK)  return (c.day_of_week < p.day_of_week) || (cur - prev > 3*86400);
   if(mode==OPEN_MONTH) return (p.mon != c.mon || p.year != c.year);
   return false;
  }

//+------------------------------------------------------------------+
//| 3) FAIR VALUE GAPS                                               |
//+------------------------------------------------------------------+
void BuildFVG(const int rates_total, const int startIdx, const datetime rightEdge,
              const datetime &time[], const double &high[], const double &low[], const double &close[])
  {
   // O'rtacha gap kengligi (o'zini-normallashtiruvchi filtr uchun).
   double sumGap=0.0; int nGap=0;
   for(int i=MathMax(startIdx,2); i<rates_total; i++)
     {
      double g1 = low[i]-high[i-2];
      double g2 = low[i-2]-high[i];
      double g = MathMax(g1,g2);
      if(g>0){ sumGap+=g; nGap++; }
     }
   double avgGap = (nGap>0)? sumGap/nGap : 0.0;
   double minWidth = InpFVG_Filter * avgGap;

   int shownPerZone[KZ_COUNT]; for(int z=0;z<KZ_COUNT;z++) shownPerZone[z]=0;
   int cnt=0;

   for(int i=MathMax(startIdx,2); i<rates_total; i++)
     {
      int zone = ZoneOfBar(time[i]);
      if(zone < 0) continue;
      if(InpFVG_Display==DISP_FIRST && shownPerZone[zone]>0) continue;

      bool bull = (low[i] > high[i-2]);
      bool bear = (high[i] < low[i-2]);
      if(!bull && !bear) continue;

      double top = bull ? low[i]   : low[i-2];
      double bot = bull ? high[i-2]: high[i];
      double width = top - bot;
      if(width < minWidth) continue;

      // Mitigatsiya tekshiruvi
      bool mitigated=false; datetime endT = rightEdge;
      for(int j=i+1; j<rates_total; j++)
        {
         if(bull && low[j] <= bot){ mitigated=true; endT=time[j]; break; }
         if(bear && high[j]>= top){ mitigated=true; endT=time[j]; break; }
        }
      if(mitigated && InpFVG_Remove) continue;
      if(!InpFVG_Extend && !mitigated) endT = time[MathMin(i+1,rates_total-1)];

      color c = bull ? InpFVG_Bull : InpFVG_Bear;
      string base = StringFormat("%sFVG_%d_", OBJ_PREFIX, cnt++);
      SetRectangle(base+"box", time[i-2], top, endT, bot, c, true, 1);
      if(InpFVG_Text)
         SetText(base+"lbl", time[i-2], (top+bot)/2.0, "FVG ", c, ANCHOR_RIGHT, 7);
      shownPerZone[zone]++;
     }
  }

//+------------------------------------------------------------------+
//| Pivot aniqlash: bar i length ta chap/o'ng bilan pivot high-mi    |
//+------------------------------------------------------------------+
bool IsPivotHigh(const int i, const int len, const int rates_total, const double &high[])
  {
   if(i-len<0 || i+len>=rates_total) return false;
   for(int k=1;k<=len;k++)
      if(high[i] < high[i-k] || high[i] < high[i+k]) return false;
   return true;
  }
bool IsPivotLow(const int i, const int len, const int rates_total, const double &low[])
  {
   if(i-len<0 || i+len>=rates_total) return false;
   for(int k=1;k<=len;k++)
      if(low[i] > low[i-k] || low[i] > low[i+k]) return false;
   return true;
  }

//+------------------------------------------------------------------+
//| 4) ORDER BLOCKS & BREAKER BLOCKS                                 |
//+------------------------------------------------------------------+
void BuildOrderBlocks(const int rates_total, const int startIdx, const datetime rightEdge,
                      const datetime &time[], const double &open[], const double &high[],
                      const double &low[], const double &close[])
  {
   int len = MathMax(1, InpOB_Swing);
   double lastPH=0, lastPL=0; int lastPHidx=-1, lastPLidx=-1;
   int shownPerZone[KZ_COUNT]; for(int z=0;z<KZ_COUNT;z++) shownPerZone[z]=0;
   int cnt=0;

   for(int i=startIdx; i<rates_total; i++)
     {
      // Tasdiqlangan pivotlarni yangilash (len bar orqada tasdiqlanadi)
      int pv = i-len;
      if(pv>=0)
        {
         if(IsPivotHigh(pv,len,rates_total,high)){ lastPH=high[pv]; lastPHidx=pv; }
         if(IsPivotLow(pv,len,rates_total,low)) { lastPL=low[pv];  lastPLidx=pv; }
        }

      // Bullish BOS: narx oxirgi pivot high ustidan yopilsa
      double mitPriceUp = (InpOB_Mitigation==MIT_CLOSE)? close[i] : high[i];
      if(lastPHidx>=0 && mitPriceUp > lastPH)
        {
         // Order Block = pivotdan i gacha bo'lgan oxirgi bearish sham
         int ob = FindLastBearish(lastPHidx, i, open, close);
         if(ob>=0)
           {
            int zone = ZoneOfBar(time[ob]);
            if(zone>=0 && (InpOB_Display==DISP_ALL || shownPerZone[zone]==0))
              {
               DrawBlock(cnt++, ob, i, time, open, high, low, close, rates_total,
                         rightEdge, true, false);
               shownPerZone[zone]++;
              }
           }
         lastPHidx=-1; // qayta ishlatmaslik
        }

      // Bearish BOS: narx oxirgi pivot low ostidan yopilsa
      double mitPriceDn = (InpOB_Mitigation==MIT_CLOSE)? close[i] : low[i];
      if(lastPLidx>=0 && mitPriceDn < lastPL)
        {
         int ob = FindLastBullish(lastPLidx, i, open, close);
         if(ob>=0)
           {
            int zone = ZoneOfBar(time[ob]);
            if(zone>=0 && (InpOB_Display==DISP_ALL || shownPerZone[zone]==0))
              {
               DrawBlock(cnt++, ob, i, time, open, high, low, close, rates_total,
                         rightEdge, false, false);
               shownPerZone[zone]++;
              }
           }
         lastPLidx=-1;
        }
     }
  }

//+------------------------------------------------------------------+
//| Diapazondagi oxirgi bearish/bullish shamni topish               |
//+------------------------------------------------------------------+
int FindLastBearish(const int from, const int to, const double &open[], const double &close[])
  {
   for(int i=to; i>=from; i--)
      if(close[i] < open[i]) return i;
   return from;
  }
int FindLastBullish(const int from, const int to, const double &open[], const double &close[])
  {
   for(int i=to; i>=from; i--)
      if(close[i] > open[i]) return i;
   return from;
  }

//+------------------------------------------------------------------+
//| Order/Breaker blokni chizish (mitigatsiya bilan)                |
//+------------------------------------------------------------------+
void DrawBlock(const int cnt, const int ob, const int bosIdx,
               const datetime &time[], const double &open[], const double &high[],
               const double &low[], const double &close[], const int rates_total,
               const datetime rightEdge, const bool bullish, const bool dummy)
  {
   double top = InpOB_UseBody ? MathMax(open[ob],close[ob]) : high[ob];
   double bot = InpOB_UseBody ? MathMin(open[ob],close[ob]) : low[ob];

   // Mitigatsiyani BOS dan keyin qidiramiz -> breaker blokka aylanadi
   bool mitigated=false; datetime endT=rightEdge; int mitIdx=rates_total-1;
   for(int j=bosIdx+1; j<rates_total; j++)
     {
      double p = (InpOB_Mitigation==MIT_CLOSE)? close[j] : (bullish? low[j] : high[j]);
      if(bullish && p < bot){ mitigated=true; mitIdx=j; break; }
      if(!bullish && p > top){ mitigated=true; mitIdx=j; break; }
     }
   if(mitigated && InpOB_Remove) return;
   if(mitigated) endT = time[mitIdx];
   else if(!InpOB_Extend) endT = time[MathMin(bosIdx+1,rates_total-1)];

   // Rang: mitigatsiya qilingan bo'lsa breaker bloki rangi
   color c;
   string tag;
   if(mitigated){ c = bullish? InpOB_BullBB : InpOB_BearBB; tag="BB"; }
   else         { c = bullish? InpOB_BullOB : InpOB_BearOB; tag="OB"; }

   string base = StringFormat("%sOB_%d_", OBJ_PREFIX, cnt);
   SetRectangle(base+"box", time[ob], top, endT, bot, c, true, 1);
   SetTrend(base+"tl", time[ob], top, endT, top, c, STYLE_SOLID, 1, false);
   SetTrend(base+"bl", time[ob], bot, endT, bot, c, STYLE_SOLID, 1, false);
   if(InpOB_Text)
      SetText(base+"lbl", time[ob], top, tag+" ", c, ANCHOR_RIGHT_LOWER, 7);
  }

//+------------------------------------------------------------------+
//| 5) MARKET STRUCTURE SHIFTS (MSS)                                |
//+------------------------------------------------------------------+
void BuildMSS(const int rates_total, const int startIdx,
              const datetime &time[], const double &high[], const double &low[], const double &close[])
  {
   int len = MathMax(1, InpMSS_Length);
   double lastPH=0, lastPL=0; int lastPHidx=-1, lastPLidx=-1;
   int trend=0; // 1=up, -1=down
   int shownPerZone[KZ_COUNT]; for(int z=0;z<KZ_COUNT;z++) shownPerZone[z]=0;
   int cnt=0;

   for(int i=startIdx; i<rates_total; i++)
     {
      int pv=i-len;
      if(pv>=0)
        {
         if(IsPivotHigh(pv,len,rates_total,high)){ lastPH=high[pv]; lastPHidx=pv; }
         if(IsPivotLow(pv,len,rates_total,low)) { lastPL=low[pv];  lastPLidx=pv; }
        }

      // Bullish MSS: pastki trendda pivot high ustidan yopilish
      if(lastPHidx>=0 && close[i]>lastPH && trend<=0)
        {
         int zone=ZoneOfBar(time[i]);
         if(zone>=0 && (InpMSS_Display==DISP_ALL || shownPerZone[zone]==0))
           {
            DrawMSS(cnt++, lastPHidx, i, lastPH, time, true);
            shownPerZone[zone]++;
           }
         trend=1; lastPHidx=-1;
        }
      // Bearish MSS: yuqori trendda pivot low ostidan yopilish
      if(lastPLidx>=0 && close[i]<lastPL && trend>=0)
        {
         int zone=ZoneOfBar(time[i]);
         if(zone>=0 && (InpMSS_Display==DISP_ALL || shownPerZone[zone]==0))
           {
            DrawMSS(cnt++, lastPLidx, i, lastPL, time, false);
            shownPerZone[zone]++;
           }
         trend=-1; lastPLidx=-1;
        }
     }
  }

//+------------------------------------------------------------------+
//| MSS chizig'i va yorlig'i                                         |
//+------------------------------------------------------------------+
void DrawMSS(const int cnt, const int pivIdx, const int breakIdx, const double level,
             const datetime &time[], const bool bullish)
  {
   color c = bullish ? InpMSS_Bull : InpMSS_Bear;
   string base = StringFormat("%sMSS_%d_", OBJ_PREFIX, cnt);
   SetTrend(base+"ln", time[pivIdx], level, time[breakIdx], level, c, STYLE_DASH, 1, false);
   if(InpMSS_Text)
      SetText(base+"lbl", time[breakIdx], level, "MSS ", c, ANCHOR_RIGHT, 7);
  }

//+------------------------------------------------------------------+
//| 6) DASHBOARD                                                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   int nowSec = SecondsOfDay(TimeCurrent());
   int rows=1;
   for(int z=0;z<KZ_COUNT;z++) if(Zones[z].enabled) rows++;
   int rowH=16, width=170, height=rows*rowH+8;

   string bg=OBJ_PREFIX+"dash_bg";
   if(ObjectFind(0,bg)<0) ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,InpDashCorner);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,InpDashX);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,InpDashY);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,InpDashBg);
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,InpDashText);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);

   int line=0;
   DashLabel("dash_hdr","ICT Killzones",InpDashText,InpDashX+8,InpDashY+4+line*rowH,true);
   line++;
   for(int z=0;z<KZ_COUNT;z++)
     {
      if(!Zones[z].enabled) continue;
      bool active=InWindow(nowSec,Zones[z].startSec,Zones[z].endSec);
      string status=active?"● FAOL":"○ yopiq";
      color rc=active?Zones[z].clr:clrGray;
      string txt=StringFormat("%-12s %s",Zones[z].name,status);
      DashLabel(StringFormat("dash_r%d",z),txt,rc,InpDashX+8,InpDashY+4+line*rowH,false);
      line++;
     }
  }

void DashLabel(const string id, const string txt, color clr, int x, int y, bool bold)
  {
   string nm=OBJ_PREFIX+id;
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,nm,OBJPROP_CORNER,InpDashCorner);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,nm,OBJPROP_TEXT,txt);
   ObjectSetString(0,nm,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,bold?9:8);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
  }
//+------------------------------------------------------------------+
