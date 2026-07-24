//+------------------------------------------------------------------+
//|                                            ICT_AMD_Manual.mq5     |
//|            ICT AMD - QO'LDA CHIZISH ASBOBI (panel + tugmalar)     |
//|                                                                   |
//|  Panel tugmalari:                                                 |
//|    A / M / D      -> AMD fazalari uchun rangli zona               |
//|    Zona (shablon) -> sozlanadigan uslub + yozuvli to'rtburchak    |
//|    Alert ON/OFF   -> zona high/low ga tekkanda OVOZLI alert       |
//|    Tozalash       -> barcha zonalarni o'chirish                   |
//|                                                                   |
//|  Zonalarni sichqoncha bilan surib/cho'zib O'ZINGIZ chizasiz.      |
//|  Yozuv zona bilan birga suriladi. Universal: har qanday           |
//|  instrument va timeframe uchun.                                   |
//+------------------------------------------------------------------+
#property copyright   "ICT AMD Manual Drawing Tool"
#property version     "2.00"
#property description "ICT AMD qo'lda chizish: A/M/D + shablon to'rtburchak (uslub+yozuv) va zona high/low ovozli alert (ON/OFF)."
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//============================ INPUTS =================================//

input string inf0 = "===== AMD ZONA RANGLARI =====";       // -----
input color  InpAccColor    = clrSlateGray;    // Accumulation (A) rangi
input color  InpManipColor  = clrCrimson;      // Manipulation (M) rangi
input color  InpDistColor   = clrTeal;         // Distribution (D) rangi

input string inf1 = "===== ZONA KO'RINISHI (umumiy) =====";// -----
input bool   InpFillZone     = true;   // Zona to'ldirilgan (fon) bo'lsinmi
input bool   InpZoneBack     = true;   // Zona shamlar ORQASIDA (fon) bo'lsinmi
input ENUM_LINE_STYLE InpZoneStyle = STYLE_SOLID; // AMD zona ramka uslubi
input int    InpZoneWidth    = 1;      // AMD zona ramka qalinligi
input color  InpLabelColor   = clrWhite;       // Yozuv rangi
input int    InpLabelFont     = 9;     // Yozuv shrifti

input string inf2 = "===== SHABLON TO'RTBURCHAK =====";     // -----
input color  InpTplColor     = clrGold;        // Shablon zona rangi
input ENUM_LINE_STYLE InpTplStyle = STYLE_DASH; // Shablon ramka uslubi
input int    InpTplWidth      = 2;     // Shablon ramka qalinligi
input bool   InpTplFill        = false;// Shablon to'ldirilganmi
input bool   InpTplBack        = true; // Shablon fon (shamlar orqasida)
input string InpTplText        = "Zona"; // Shablon yozuvi

input string inf3 = "===== OVOZLI ALERT =====";             // -----
input bool   InpAlertsDefault  = true; // Boshlanishida alert yoqiqmi
input string InpSoundHigh      = "alert.wav";   // HIGH ga tekkandagi ovoz
input string InpSoundLow       = "alert2.wav";  // LOW ga tekkandagi ovoz
input bool   InpPopupAlert     = false;// Ovoz bilan birga oyna-alert ham chiqsinmi

input string inf4 = "===== PANEL =====";                    // -----
input ENUM_BASE_CORNER InpCorner = CORNER_LEFT_UPPER;  // Panel burchagi
input int    InpPanelX       = 12;     // Panel X masofasi (px)
input int    InpPanelY       = 24;     // Panel Y masofasi (px)
input int    InpBtnW         = 130;    // Tugma kengligi (px)
input int    InpBtnH         = 26;     // Tugma balandligi (px)
input int    InpBtnGap       = 4;      // Tugmalar orasidagi masofa (px)
input int    InpBtnFont      = 9;      // Tugma shrifti
input color  InpBtnTextColor = clrWhite;       // Tugma matn rangi

//========================== GLOBALS =================================//

string gBtn  = "AMDM_btn_";        // tugmalar prefiksi
string gZone = "AMDM_zone_";       // chizilgan zonalar prefiksi
int    gZoneId = 0;
bool   gAlertsOn = true;

// alertlarni takrorlamaslik uchun har zona holati
string gZN[];      // zona nomi
bool   gAbove[];   // hozir HIGH ustidami
bool   gBelow[];   // hozir LOW ostidami

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "ICT AMD Manual");
   gZoneId   = 0;
   gAlertsOn = InpAlertsDefault;
   ArrayResize(gZN, 0);
   ArrayResize(gAbove, 0);
   ArrayResize(gBelow, 0);
   BuildPanel();
   EventSetTimer(1);   // alert monitoringi uchun (sekundlik)
   ChartRedraw();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, gBtn);
   if(reason == REASON_REMOVE)
      ObjectsDeleteAll(0, gZone);
   ChartRedraw();
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   // har tikda ham alertni tekshiramiz (tez reaksiya uchun)
   CheckAlerts();
   return(rates_total);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   // sekin bozorda ham ishlashi uchun taymer bo'yicha tekshiramiz
   CheckAlerts();
}

//============================ PANEL =================================//

void BuildPanel()
{
   ObjectsDeleteAll(0, gBtn);
   int y = InpPanelY;
   CreateButton("A",   "A  Accumulation",  y, InpAccColor);   y += InpBtnH + InpBtnGap;
   CreateButton("M",   "M  Manipulation",  y, InpManipColor); y += InpBtnH + InpBtnGap;
   CreateButton("D",   "D  Distribution",  y, InpDistColor);  y += InpBtnH + InpBtnGap;
   CreateButton("TPL", "+  Zona (shablon)",y, InpTplColor);   y += InpBtnH + InpBtnGap;
   CreateButton("ALR", AlertBtnText(),     y, AlertBtnColor());y+= InpBtnH + InpBtnGap;
   CreateButton("CLR", "Tozalash (zonalar)",y,clrDimGray);
}

string AlertBtnText()  { return gAlertsOn ? "Alert: ON (ovoz)" : "Alert: OFF"; }
color  AlertBtnColor() { return gAlertsOn ? clrForestGreen : clrFireBrick; }

void CreateButton(string key, string text, int y, color bg)
{
   string name = gBtn + key;
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, InpBtnW);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, InpBtnH);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpBtnTextColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpBtnFont);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
}

//============================ EVENTS ================================//

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == gBtn+"A")        { CreateZone("Accumulation", InpAccColor, InpZoneStyle, InpZoneWidth, InpFillZone, InpZoneBack, "A - Accumulation"); ResetBtn(sparam); }
      else if(sparam == gBtn+"M")   { CreateZone("Manipulation", InpManipColor, InpZoneStyle, InpZoneWidth, InpFillZone, InpZoneBack, "M - Manipulation"); ResetBtn(sparam); }
      else if(sparam == gBtn+"D")   { CreateZone("Distribution", InpDistColor, InpZoneStyle, InpZoneWidth, InpFillZone, InpZoneBack, "D - Distribution"); ResetBtn(sparam); }
      else if(sparam == gBtn+"TPL") { CreateZone("Zona", InpTplColor, InpTplStyle, InpTplWidth, InpTplFill, InpTplBack, InpTplText); ResetBtn(sparam); }
      else if(sparam == gBtn+"ALR") { gAlertsOn = !gAlertsOn; UpdateAlertBtn(); ResetBtn(sparam); }
      else if(sparam == gBtn+"CLR") { ClearZones(); ResetBtn(sparam); }
      return;
   }

   // zona surilganda yozuvni ham birga ko'chiramiz
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      if(StringFind(sparam, gZone) == 0 && StringFind(sparam, "_lbl") < 0)
         RepositionLabel(sparam);
      return;
   }
}

void ResetBtn(string name){ ObjectSetInteger(0, name, OBJPROP_STATE, false); }

void UpdateAlertBtn()
{
   string name = gBtn+"ALR";
   ObjectSetString (0, name, OBJPROP_TEXT, AlertBtnText());
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, AlertBtnColor());
   ChartRedraw();
}

//============================ ZONALAR ==============================//

void CreateZone(string type, color clr, ENUM_LINE_STYLE style, int width,
                bool fill, bool back, string text)
{
   datetime t1, t2; double p1, p2;
   DefaultBox(t1, t2, p1, p2);

   string name = gZone + type + "_" + (string)(gZoneId++);
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2))
      return;
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, text);

   // yozuv (label)
   if(StringLen(text) > 0)
   {
      string lbl = name + "_lbl";
      ObjectCreate(0, lbl, OBJ_TEXT, 0, t1, MathMax(p1,p2));
      ObjectSetString (0, lbl, OBJPROP_TEXT, " "+text);
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, InpLabelColor);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, InpLabelFont);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lbl, OBJPROP_BACK, false);
   }

   // alert holatini boshlang'ich narxga qarab o'rnatamiz (darrov chiqmasligi uchun)
   RegisterZone(name);
   ChartRedraw();
}

void RepositionLabel(string zoneName)
{
   string lbl = zoneName + "_lbl";
   if(ObjectFind(0, lbl) < 0) return;
   datetime t1 = (datetime)ObjectGetInteger(0, zoneName, OBJPROP_TIME, 0);
   datetime t2 = (datetime)ObjectGetInteger(0, zoneName, OBJPROP_TIME, 1);
   double   p1 = ObjectGetDouble(0, zoneName, OBJPROP_PRICE, 0);
   double   p2 = ObjectGetDouble(0, zoneName, OBJPROP_PRICE, 1);
   datetime tLeft = (t1 < t2) ? t1 : t2;
   double   pTop  = MathMax(p1, p2);
   ObjectMove(0, lbl, 0, tLeft, pTop);
}

void ClearZones()
{
   ObjectsDeleteAll(0, gZone);
   ArrayResize(gZN, 0);
   ArrayResize(gAbove, 0);
   ArrayResize(gBelow, 0);
   ChartRedraw();
}

//============================ ALERT =================================//

int FindZoneState(string name)
{
   for(int i=0; i<ArraySize(gZN); i++)
      if(gZN[i] == name) return i;
   return -1;
}

void RegisterZone(string name)
{
   if(FindZoneState(name) >= 0) return;
   double hi, lo; if(!ZoneHiLo(name, hi, lo)) return;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int k = ArraySize(gZN);
   ArrayResize(gZN, k+1);
   ArrayResize(gAbove, k+1);
   ArrayResize(gBelow, k+1);
   gZN[k]    = name;
   gAbove[k] = (price >= hi);
   gBelow[k] = (price <= lo);
}

bool ZoneHiLo(string name, double &hi, double &lo)
{
   if(ObjectFind(0, name) < 0) return false;
   double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   double p2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
   hi = MathMax(p1, p2);
   lo = MathMin(p1, p2);
   return true;
}

void CheckAlerts()
{
   if(!gAlertsOn) return;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0) return;

   int tot = ObjectsTotal(0, 0);
   for(int i=0; i<tot; i++)
   {
      string name = ObjectName(0, i, 0);
      if(StringFind(name, gZone) != 0) continue;
      if(StringFind(name, "_lbl") >= 0) continue;

      double hi, lo;
      if(!ZoneHiLo(name, hi, lo)) continue;

      int idx = FindZoneState(name);
      if(idx < 0){ RegisterZone(name); idx = FindZoneState(name); if(idx < 0) continue; }

      // HIGH chizig'i
      if(price >= hi)
      {
         if(!gAbove[idx]){ FireAlert(name, hi, true); gAbove[idx] = true; }
      }
      else gAbove[idx] = false;

      // LOW chizig'i
      if(price <= lo)
      {
         if(!gBelow[idx]){ FireAlert(name, lo, false); gBelow[idx] = true; }
      }
      else gBelow[idx] = false;
   }
}

void FireAlert(string name, double level, bool isHigh)
{
   string snd = isHigh ? InpSoundHigh : InpSoundLow;
   if(StringLen(snd) > 0)
      PlaySound(snd);

   if(InpPopupAlert)
   {
      string edge = isHigh ? "HIGH" : "LOW";
      Alert(_Symbol, " ", EnumToString((ENUM_TIMEFRAMES)_Period),
            " Zona ", edge, " @ ", DoubleToString(level, _Digits),
            "  (", ZoneTitle(name), ")");
   }
}

string ZoneTitle(string name)
{
   string tip = ObjectGetString(0, name, OBJPROP_TOOLTIP);
   return (StringLen(tip) > 0) ? tip : "zona";
}

//============================ DEFAULT BOX ===========================//

void DefaultBox(datetime &t1, datetime &t2, double &p1, double &p2)
{
   int fvb = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int vb  = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   if(vb < 10) vb = 30;

   int centerShift = fvb - vb/2;
   if(centerShift < 2) centerShift = 10;
   int half = MathMax(2, vb/10);
   int leftShift  = centerShift + half;
   int rightShift = centerShift - half;
   if(rightShift < 0) rightShift = 0;

   t1 = iTime(_Symbol, _Period, leftShift);
   t2 = iTime(_Symbol, _Period, rightShift);
   if(t1 == 0) t1 = iTime(_Symbol, _Period, 15);
   if(t2 == 0) t2 = iTime(_Symbol, _Period, 3);
   if(t2 <= t1) t2 = t1 + PeriodSeconds(_Period)*10;

   double pmin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   double pmax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   if(pmax <= pmin)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      pmax = bid * 1.01;
      pmin = bid * 0.99;
   }
   double mid  = (pmin + pmax) * 0.5;
   double band = (pmax - pmin) * 0.12;
   p1 = mid + band;
   p2 = mid - band;
}
//+------------------------------------------------------------------+
