//+------------------------------------------------------------------+
//|                                               ICT_Killzones.mq5   |
//|                  ICT Killzones + Sessions (LuxAlgo style clone)   |
//|                                                                  |
//|  A full MQL5 re-implementation of the popular "ICT Killzones +   |
//|  Sessions" toolkit concept for MetaTrader 5.                     |
//|                                                                  |
//|  Features:                                                       |
//|   - 4 ICT Killzones: New York, London Open, London Close, Asia   |
//|   - Session range boxes (high / low) with fill + border         |
//|   - Session high / low horizontal lines (optionally extended)    |
//|   - Mean threshold (50% equilibrium) line                        |
//|   - Session name labels                                          |
//|   - Pivot high / low detection inside each killzone              |
//|   - Info dashboard (table) with per-session status               |
//|   - Configurable timezone offset (broker time alignment)         |
//|                                                                  |
//|  NOTE: This is an original, independent implementation written   |
//|        from the public ICT killzone specification. It is NOT a   |
//|        copy of LuxAlgo's proprietary Pine Script source.         |
//+------------------------------------------------------------------+
#property copyright   "Open implementation - ICT Killzones for MT5"
#property link        ""
#property version     "1.00"
#property description "ICT Killzones + Sessions (New York / London Open / London Close / Asia)"
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_YESNO
  {
   YES = 1,   // Yes
   NO  = 0    // No
  };

//+------------------------------------------------------------------+
//| Inputs - General                                                 |
//+------------------------------------------------------------------+
input group "════════ General ════════"
input int    InpTimezoneOffset  = 0;        // Broker offset (hours) to add to killzone times
input int    InpDaysToShow       = 10;      // History: number of days to display
input bool   InpShowBoxes        = true;    // Show killzone range boxes
input bool   InpShowLabels       = true;    // Show killzone name labels
input bool   InpShowHighLow      = true;    // Show session High/Low lines
input bool   InpExtendHighLow    = true;    // Extend High/Low lines to the right
input bool   InpShowMean         = true;    // Show mean threshold (50%) line
input bool   InpShowPivots       = true;    // Show pivots inside killzones
input int    InpPivotStrength    = 2;       // Pivot strength (bars on each side)
input bool   InpFillBoxes        = true;    // Fill boxes (transparent background)
input int    InpLineWidth        = 1;       // Border / line width

input group "════════ New York Killzone ════════"
input bool   InpNY_On     = true;           // Enable New York
input string InpNY_Name   = "New York";     // Label
input string InpNY_Start  = "07:00";        // Start (HH:MM)
input string InpNY_End    = "10:00";        // End   (HH:MM)
input color  InpNY_Color  = clrDodgerBlue;  // Color

input group "════════ London Open Killzone ════════"
input bool   InpLO_On     = true;           // Enable London Open
input string InpLO_Name   = "London Open";  // Label
input string InpLO_Start  = "02:00";        // Start (HH:MM)
input string InpLO_End    = "05:00";        // End   (HH:MM)
input color  InpLO_Color  = clrOrange;      // Color

input group "════════ London Close Killzone ════════"
input bool   InpLC_On     = true;           // Enable London Close
input string InpLC_Name   = "London Close"; // Label
input string InpLC_Start  = "10:00";        // Start (HH:MM)
input string InpLC_End    = "12:00";        // End   (HH:MM)
input color  InpLC_Color  = clrMediumOrchid;// Color

input group "════════ Asia Killzone ════════"
input bool   InpAS_On     = true;           // Enable Asia
input string InpAS_Name   = "Asia";         // Label
input string InpAS_Start  = "20:00";        // Start (HH:MM)
input string InpAS_End    = "00:00";        // End   (HH:MM)
input color  InpAS_Color  = clrLimeGreen;   // Color

input group "════════ Dashboard ════════"
input bool             InpShowDashboard = true;              // Show dashboard table
input ENUM_BASE_CORNER InpDashCorner    = CORNER_RIGHT_UPPER;// Corner
input int              InpDashX          = 10;               // X offset (px)
input int              InpDashY          = 20;               // Y offset (px)
input color            InpDashText       = clrWhite;         // Dashboard text color
input color            InpDashBg         = clrBlack;         // Dashboard background

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+
#define KZ_COUNT   4
#define OBJ_PREFIX "ICTKZ_"

//+------------------------------------------------------------------+
//| Killzone definition structure                                    |
//+------------------------------------------------------------------+
struct KillzoneDef
  {
   bool     enabled;
   string   name;
   int      startSec;    // seconds from midnight
   int      endSec;      // seconds from midnight
   color    clr;
  };

KillzoneDef Zones[KZ_COUNT];

//+------------------------------------------------------------------+
//| Helper: parse "HH:MM" into seconds from midnight                 |
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
//| Helper: seconds-of-day for a datetime with offset applied        |
//+------------------------------------------------------------------+
int SecondsOfDay(const datetime t)
  {
   datetime shifted = t + (datetime)(InpTimezoneOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(shifted, dt);
   return dt.hour * 3600 + dt.min * 60 + dt.sec;
  }

//+------------------------------------------------------------------+
//| Helper: midnight (with offset) of the day containing t           |
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
//| Helper: is a given time-of-day (sec) inside a killzone window    |
//| Handles windows crossing midnight (start > end).                 |
//+------------------------------------------------------------------+
bool InWindow(const int sec, const int startSec, const int endSec)
  {
   if(startSec == endSec)
      return false;
   if(startSec < endSec)
      return (sec >= startSec && sec < endSec);
   // crosses midnight (e.g. 20:00 -> 00:00 handled as 00:00 == 0 => wrap)
   return (sec >= startSec || sec < endSec);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // New York
   Zones[0].enabled  = InpNY_On;
   Zones[0].name     = InpNY_Name;
   Zones[0].startSec = ParseTimeToSec(InpNY_Start);
   Zones[0].endSec   = ParseTimeToSec(InpNY_End);
   Zones[0].clr      = InpNY_Color;
   // London Open
   Zones[1].enabled  = InpLO_On;
   Zones[1].name     = InpLO_Name;
   Zones[1].startSec = ParseTimeToSec(InpLO_Start);
   Zones[1].endSec   = ParseTimeToSec(InpLO_End);
   Zones[1].clr      = InpLO_Color;
   // London Close
   Zones[2].enabled  = InpLC_On;
   Zones[2].name     = InpLC_Name;
   Zones[2].startSec = ParseTimeToSec(InpLC_Start);
   Zones[2].endSec   = ParseTimeToSec(InpLC_End);
   Zones[2].clr      = InpLC_Color;
   // Asia
   Zones[3].enabled  = InpAS_On;
   Zones[3].name     = InpAS_Name;
   Zones[3].startSec = ParseTimeToSec(InpAS_Start);
   // 00:00 end means end of day -> treat as 24:00 to avoid zero window
   Zones[3].endSec   = ParseTimeToSec(InpAS_End);
   Zones[3].clr      = InpAS_Color;

   IndicatorSetString(INDICATOR_SHORTNAME, "ICT Killzones");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Object creation helpers                                          |
//+------------------------------------------------------------------+
void CreateRectangle(const string name, datetime t1, double p1, datetime t2, double p2,
                     color clr, bool fill, int width)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   else
     {
      ObjectMove(0, name, 0, t1, p1);
      ObjectMove(0, name, 1, t2, p2);
     }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void CreateTrendLine(const string name, datetime t1, double p1, datetime t2, double p2,
                     color clr, ENUM_LINE_STYLE style, int width, bool ray)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   else
     {
      ObjectMove(0, name, 0, t1, p1);
      ObjectMove(0, name, 1, t2, p2);
     }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, ray);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void CreateText(const string name, datetime t, double p, const string txt,
                color clr, ENUM_ANCHOR_POINT anchor)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   else
      ObjectMove(0, name, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void CreateArrow(const string name, datetime t, double p, int code, color clr,
                 ENUM_ANCHOR_POINT anchor)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, t, p);
   else
      ObjectMove(0, name, 0, t, p);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Main calculation                                                 |
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
   if(rates_total < 10)
      return(rates_total);

   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   // Only fully rebuild when a new bar appears (or first run) to save CPU.
   static int lastRates = 0;
   bool newBar = (rates_total != lastRates);
   if(!newBar && prev_calculated > 0)
     {
      // Still update the most recent (forming) session boxes each tick.
      // Cheap path: full rebuild is skipped; nothing else needed.
      return(rates_total);
     }
   lastRates = rates_total;

   // Clear previous objects (bounded rebuild).
   ObjectsDeleteAll(0, OBJ_PREFIX);

   // Determine the earliest time we care about (InpDaysToShow days back).
   datetime cutoff = time[rates_total - 1] - (datetime)((long)InpDaysToShow * 86400);

   // Find starting bar index at or after cutoff.
   int startIdx = 0;
   for(int i = rates_total - 1; i >= 0; i--)
     {
      if(time[i] < cutoff)
        {
         startIdx = i + 1;
         break;
        }
     }
   if(startIdx < 0) startIdx = 0;
   if(startIdx > rates_total - 1) startIdx = 0;

   // Per-zone session tracking state.
   datetime sessKey[KZ_COUNT];      // day-start key of current session
   datetime sessStartT[KZ_COUNT];   // first bar time of session
   double   sessHigh[KZ_COUNT];
   double   sessLow[KZ_COUNT];
   int      sessCount[KZ_COUNT];    // how many sessions drawn (for unique names)
   bool     sessActive[KZ_COUNT];

   for(int z = 0; z < KZ_COUNT; z++)
     {
      sessKey[z]    = 0;
      sessStartT[z] = 0;
      sessHigh[z]   = -DBL_MAX;
      sessLow[z]    = DBL_MAX;
      sessCount[z]  = 0;
      sessActive[z] = false;
     }

   // Iterate bars in chronological order.
   for(int i = startIdx; i < rates_total; i++)
     {
      int sec = SecondsOfDay(time[i]);

      for(int z = 0; z < KZ_COUNT; z++)
        {
         if(!Zones[z].enabled)
            continue;

         bool inside = InWindow(sec, Zones[z].startSec, Zones[z].endSec);

         if(inside)
           {
            // Session identity key: for windows crossing midnight the key is
            // the day-start of the bar that opened the session.
            datetime key = DayStart(time[i]);
            // For midnight-crossing zones, keep the same session while active.
            if(sessActive[z] && Zones[z].startSec > Zones[z].endSec)
               key = sessKey[z];

            if(!sessActive[z] || key != sessKey[z])
              {
               // Close previous (already drawn incrementally) & start new.
               sessActive[z]  = true;
               sessKey[z]     = DayStart(time[i]);
               sessStartT[z]  = time[i];
               sessHigh[z]    = high[i];
               sessLow[z]     = low[i];
               sessCount[z]++;
              }
            else
              {
               if(high[i] > sessHigh[z]) sessHigh[z] = high[i];
               if(low[i]  < sessLow[z])  sessLow[z]  = low[i];
              }

            // Draw / update this session's graphics.
            DrawSession(z, sessCount[z], sessStartT[z], time[i],
                        sessHigh[z], sessLow[z], false,
                        high, low, i, startIdx);
           }
         else
           {
            if(sessActive[z])
              {
               // Session just ended -> finalize with last known bounds.
               sessActive[z] = false;
               // Redraw final version (extend high/low as configured).
               DrawSession(z, sessCount[z], sessStartT[z], time[i - 1 >= 0 ? i - 1 : i],
                           sessHigh[z], sessLow[z], true,
                           high, low, i, startIdx);
              }
           }
        }
     }

   // Draw pivots inside killzones (separate pass so full session bounds known).
   if(InpShowPivots)
      DrawPivots(rates_total, startIdx, time, high, low);

   // Dashboard
   if(InpShowDashboard)
      UpdateDashboard(rates_total, time, high, low, close);

   ChartRedraw(0);
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Draw one session's box / lines / label / mean                    |
//+------------------------------------------------------------------+
void DrawSession(const int z, const int idx, datetime t1, datetime t2,
                 double hi, double lo, bool finalized,
                 const double &high[], const double &low[], int barIdx, int startIdx)
  {
   string base = StringFormat("%s%d_%d_", OBJ_PREFIX, z, idx);
   color  c    = Zones[z].clr;

   // Rectangle box
   if(InpShowBoxes)
     {
      CreateRectangle(base + "box", t1, hi, t2, lo, c, InpFillBoxes, InpLineWidth);
     }

   // High / Low lines
   if(InpShowHighLow)
     {
      datetime hlEnd = t2;
      bool ray = false;
      if(InpExtendHighLow)
        {
         ray = true;   // extend to the right edge
        }
      CreateTrendLine(base + "hi", t1, hi, hlEnd, hi, c, STYLE_SOLID, InpLineWidth, ray);
      CreateTrendLine(base + "lo", t1, lo, hlEnd, lo, c, STYLE_SOLID, InpLineWidth, ray);
     }

   // Mean threshold (50%)
   if(InpShowMean)
     {
      double mean = (hi + lo) / 2.0;
      CreateTrendLine(base + "mean", t1, mean, t2, mean, c, STYLE_DOT, 1, false);
     }

   // Label
   if(InpShowLabels)
     {
      string txt = Zones[z].name;
      CreateText(base + "lbl", t1, hi, "  " + txt, c, ANCHOR_LEFT_LOWER);
     }
  }

//+------------------------------------------------------------------+
//| Pivot detection inside killzones                                 |
//+------------------------------------------------------------------+
void DrawPivots(const int rates_total, const int startIdx,
                const datetime &time[], const double &high[], const double &low[])
  {
   int L = InpPivotStrength;
   if(L < 1) L = 1;

   int from = MathMax(startIdx, L);
   int to   = rates_total - L - 1;

   for(int i = from; i <= to; i++)
     {
      // Which killzone (if any) does bar i belong to?
      int sec = SecondsOfDay(time[i]);
      int zone = -1;
      for(int z = 0; z < KZ_COUNT; z++)
        {
         if(Zones[z].enabled && InWindow(sec, Zones[z].startSec, Zones[z].endSec))
           {
            zone = z;
            break;
           }
        }
      if(zone < 0)
         continue;

      // Pivot high
      bool isHigh = true;
      bool isLow  = true;
      for(int k = 1; k <= L; k++)
        {
         if(high[i] <= high[i - k] || high[i] < high[i + k]) isHigh = false;
         if(low[i]  >= low[i - k]  || low[i]  > low[i + k])  isLow  = false;
        }

      if(isHigh)
        {
         string nm = StringFormat("%spiv_h_%d", OBJ_PREFIX, i);
         CreateArrow(nm, time[i], high[i], 234 /*down triangle*/, Zones[zone].clr, ANCHOR_BOTTOM);
        }
      if(isLow)
        {
         string nm = StringFormat("%spiv_l_%d", OBJ_PREFIX, i);
         CreateArrow(nm, time[i], low[i], 233 /*up triangle*/, Zones[zone].clr, ANCHOR_TOP);
        }
     }
  }

//+------------------------------------------------------------------+
//| Dashboard table                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard(const int rates_total, const datetime &time[],
                     const double &high[], const double &low[], const double &close[])
  {
   int nowSec = SecondsOfDay(TimeCurrent());

   // Background panel
   string bg = OBJ_PREFIX + "dash_bg";
   int rows = 1;
   for(int z = 0; z < KZ_COUNT; z++)
      if(Zones[z].enabled) rows++;

   int rowH   = 16;
   int width  = 150;
   int height = rows * rowH + 8;

   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, InpDashCorner);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, InpDashX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, InpDashY);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, InpDashBg);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, InpDashText);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);

   // Header
   int line = 0;
   DashLabel("dash_hdr", "ICT Killzones", InpDashText, InpDashX + 8,
             InpDashY + 4 + line * rowH, true);
   line++;

   for(int z = 0; z < KZ_COUNT; z++)
     {
      if(!Zones[z].enabled)
         continue;
      bool active = InWindow(nowSec, Zones[z].startSec, Zones[z].endSec);
      string status = active ? "● ACTIVE" : "○ closed";
      color  rc     = active ? Zones[z].clr : clrGray;
      string txt    = StringFormat("%-12s %s", Zones[z].name, status);
      DashLabel(StringFormat("dash_r%d", z), txt, rc, InpDashX + 8,
                InpDashY + 4 + line * rowH, false);
      line++;
     }
  }

//+------------------------------------------------------------------+
//| Dashboard text label helper                                      |
//+------------------------------------------------------------------+
void DashLabel(const string id, const string txt, color clr, int x, int y, bool bold)
  {
   string nm = OBJ_PREFIX + id;
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nm, OBJPROP_CORNER, InpDashCorner);
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetString(0, nm, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, bold ? 9 : 8);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
  }
//+------------------------------------------------------------------+
