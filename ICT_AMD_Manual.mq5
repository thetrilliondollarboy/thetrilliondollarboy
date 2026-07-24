//+------------------------------------------------------------------+
//|                                            ICT_AMD_Manual.mq5     |
//|            ICT AMD - QO'LDA CHIZISH ASBOBI (panel + tugmalar)     |
//|                                                                   |
//|  Ekran chetida panel: A / M / D / Tozalash tugmalari.            |
//|  Tugmani bosganda o'sha fazaning rangidagi to'ldirilgan          |
//|  to'rtburchak (zona) hosil bo'ladi. Uni sichqoncha bilan surib,  |
//|  cho'zib kerakli joyga OZINGIZ chizasiz.                          |
//|                                                                   |
//|  Universal: har qanday instrument va timeframe uchun.            |
//+------------------------------------------------------------------+
#property copyright   "ICT AMD Manual Drawing Tool"
#property version     "1.00"
#property description "ICT AMD qo'lda chizish: A/M/D tugmalari orqali rangli fon to'rtburchagi qo'yiladi, siz uni surib zonani o'zingiz chizasiz."
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//============================ INPUTS =================================//

input string inf0 = "===== ZONA RANGLARI =====";           // -----
input color  InpAccColor    = clrSlateGray;    // Accumulation (A) rangi
input color  InpManipColor  = clrCrimson;      // Manipulation (M) rangi
input color  InpDistColor   = clrTeal;         // Distribution (D) rangi
input bool   InpFillZone     = true;   // Zona to'ldirilgan (fon) bo'lsinmi
input bool   InpZoneBack     = true;   // Zona shamlar ORQASIDA (fon) bo'lsinmi
input int    InpZoneStyle    = STYLE_SOLID;  // Zona ramka uslubi (0..4)
input int    InpZoneWidth    = 1;      // Zona ramka qalinligi

input string inf1 = "===== PANEL =====";                    // -----
input ENUM_BASE_CORNER InpCorner = CORNER_LEFT_UPPER;  // Panel burchagi
input int    InpPanelX       = 12;     // Panel X masofasi (px)
input int    InpPanelY       = 24;     // Panel Y masofasi (px)
input int    InpBtnW         = 120;    // Tugma kengligi (px)
input int    InpBtnH         = 26;     // Tugma balandligi (px)
input int    InpBtnGap       = 4;      // Tugmalar orasidagi masofa (px)
input int    InpBtnFont      = 9;      // Tugma shrifti
input color  InpBtnTextColor = clrWhite;       // Tugma matn rangi

//========================== GLOBALS =================================//

string gPrefix   = "AMDM_";            // umumiy prefiks
string gBtn      = "AMDM_btn_";        // tugmalar prefiksi
string gZone     = "AMDM_zone_";       // chizilgan zonalar prefiksi
int    gZoneId   = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "ICT AMD Manual");
   gZoneId = 0;
   BuildPanel();
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartRedraw();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // faqat panel tugmalarini o'chiramiz; foydalanuvchi chizgan zonalar qoladi
   ObjectsDeleteAll(0, gBtn);
   // agar indikator grafikdan butunlay olib tashlansa, zonalarni ham tozalaymiz
   if(reason == REASON_REMOVE)
      ObjectsDeleteAll(0, gZone);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Indikatorning hisob-kitobi yo'q - bu faqat chizish asbobi        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Panel tugmalarini yaratish                                       |
//+------------------------------------------------------------------+
void BuildPanel()
{
   ObjectsDeleteAll(0, gBtn);
   int y = InpPanelY;
   CreateButton("A", "A  Accumulation", y, InpAccColor);
   y += InpBtnH + InpBtnGap;
   CreateButton("M", "M  Manipulation", y, InpManipColor);
   y += InpBtnH + InpBtnGap;
   CreateButton("D", "D  Distribution", y, InpDistColor);
   y += InpBtnH + InpBtnGap;
   CreateButton("CLR", "Tozalash (zonalar)", y, clrDimGray);
}

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Grafik hodisalari (tugma bosilishi)                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == gBtn+"A")
   {
      CreateZone("Accumulation", InpAccColor);
      ResetButton(sparam);
   }
   else if(sparam == gBtn+"M")
   {
      CreateZone("Manipulation", InpManipColor);
      ResetButton(sparam);
   }
   else if(sparam == gBtn+"D")
   {
      CreateZone("Distribution", InpDistColor);
      ResetButton(sparam);
   }
   else if(sparam == gBtn+"CLR")
   {
      ObjectsDeleteAll(0, gZone);
      ResetButton(sparam);
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Tugmani bosilgan holatdan qaytarish                              |
//+------------------------------------------------------------------+
void ResetButton(string name)
{
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| Yangi zona (surib chiziladigan to'rtburchak) yaratish            |
//+------------------------------------------------------------------+
void CreateZone(string label, color clr)
{
   datetime t1, t2;
   double   p1, p2;
   DefaultBox(t1, t2, p1, p2);

   string name = gZone + label + "_" + (string)(gZoneId++);
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2))
      return;

   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, InpFillZone);
   ObjectSetInteger(0, name, OBJPROP_BACK, InpZoneBack);
   ObjectSetInteger(0, name, OBJPROP_STYLE, (ENUM_LINE_STYLE)InpZoneStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpZoneWidth);
   // MUHIM: surib/cho'zib chizish uchun tanlanadigan qilamiz
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, label);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Ko'rinib turgan oynaning markazida standart quti koordinatalari  |
//+------------------------------------------------------------------+
void DefaultBox(datetime &t1, datetime &t2, double &p1, double &p2)
{
   // vaqt bo'yicha: ko'rinadigan barlarning markazi atrofida
   int fvb = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);   // eng chapdagi bar (series indeks)
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

   // narx bo'yicha: ko'rinadigan diapazon markazi atrofida
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
   p1 = mid + band;   // yuqori chet
   p2 = mid - band;   // pastki chet
}
//+------------------------------------------------------------------+
