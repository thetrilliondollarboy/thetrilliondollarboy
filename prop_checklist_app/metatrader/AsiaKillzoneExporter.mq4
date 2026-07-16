//+------------------------------------------------------------------+
//|                                       AsiaKillzoneExporter.mq4    |
//|   ICT Prop Checklist uchun eksport EA (MetaTrader 4)             |
//|   Vazifasi: MT5 versiyasi bilan bir xil — killzone/sweep/MSS ni  |
//|   JSON faylga yozadi. Fayl: <MT4 Data Folder>/MQL4/Files/ ichida |
//|   ESLATMA: bu EA savdo qilmaydi — faqat ma'lumot eksport qiladi. |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0"

input string  OutFile          = "killzone_data.json";
input int     WriteEverySec    = 2;
input int     AsiaStartHour    = 20;
input int     AsiaEndHour      = 0;
input bool    UseForexKZ       = true;
input int     LondonStart      = 2;    input int LondonEnd      = 5;
input int     NYStart          = 7;    input int NYEnd          = 10;
input int     LonCloseStart    = 10;   input int LonCloseEnd    = 12;
input int     NYStartIdx       = 8;    input int NYEndIdx       = 11;
input int     LonCloseStartIdx = 13;   input int LonCloseEndIdx = 16;
input int     MSS_TF           = PERIOD_M5;
input int     MSS_Lookback     = 12;
input bool    UseNewsWindow    = false;
input string  NewsTimesCSV     = "";
input int     NewsPadMin       = 30;

datetime g_lastWrite = 0;

int OnInit(){ EventSetTimer(1); WriteData(); return(INIT_SUCCEEDED); }
void OnDeinit(const int reason){ EventKillTimer(); }
void OnTick(){ MaybeWrite(); }
void OnTimer(){ MaybeWrite(); }

void MaybeWrite()
{
   if(TimeCurrent() - g_lastWrite >= WriteEverySec)
   {
      WriteData();
      g_lastWrite = TimeCurrent();
   }
}

datetime DayStart(datetime t)
{
   MqlDateTime s; TimeToStruct(t, s);
   s.hour = 0; s.min = 0; s.sec = 0;
   return StructToTime(s);
}

void CalcAsia(double &ah, double &al, datetime &asiaEnd)
{
   ah = 0; al = 0;
   datetime now = TimeCurrent();
   datetime today0 = DayStart(now);
   datetime aStart, aEnd;
   if(AsiaStartHour >= AsiaEndHour)
   {
      aStart = today0 - 86400 + AsiaStartHour*3600;
      aEnd   = today0 + AsiaEndHour*3600;
   }
   else
   {
      aStart = today0 + AsiaStartHour*3600;
      aEnd   = today0 + AsiaEndHour*3600;
   }
   asiaEnd = aEnd;
   int i1 = iBarShift(_Symbol, PERIOD_M15, aStart, false);
   int i2 = iBarShift(_Symbol, PERIOD_M15, aEnd, false);
   if(i1 < 0 || i2 < 0) return;
   int from = MathMin(i1, i2);
   int to   = MathMax(i1, i2);
   double hi = -1, lo = 1e18;
   for(int i = from; i <= to; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M15, i);
      double l = iLow(_Symbol, PERIOD_M15, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
   }
   if(hi > 0){ ah = hi; al = lo; }
}

void CalcPrevDay(double &pdh, double &pdl)
{
   pdh = iHigh(_Symbol, PERIOD_D1, 1);
   pdl = iLow(_Symbol, PERIOD_D1, 1);
}

string CurrentKillzone()
{
   MqlDateTime s; TimeToStruct(TimeCurrent(), s);
   int h = s.hour;
   bool asia = (AsiaStartHour >= AsiaEndHour)
             ? (h >= AsiaStartHour || h < AsiaEndHour)
             : (h >= AsiaStartHour && h < AsiaEndHour);
   if(asia) return "Asian";
   if(h >= LondonStart && h < LondonEnd) return "London";
   if(UseForexKZ)
   {
      if(h >= NYStart && h < NYEnd) return "NewYork";
      if(h >= LonCloseStart && h < LonCloseEnd) return "LondonClose";
   }
   else
   {
      if(h >= NYStartIdx && h < NYEndIdx) return "NewYork";
      if(h >= LonCloseStartIdx && h < LonCloseEndIdx) return "LondonClose";
   }
   return "None";
}

void CalcSweeps(double ah, double al, double pdh, double pdl,
                bool &alSwept, bool &ahSwept, bool &pdhSwept, bool &pdlSwept)
{
   alSwept = false; ahSwept = false; pdhSwept = false; pdlSwept = false;
   datetime today0 = DayStart(TimeCurrent());
   int idx = iBarShift(_Symbol, PERIOD_M15, today0, false);
   if(idx < 0) idx = 20;
   double dayHi = -1, dayLo = 1e18;
   for(int i = 0; i <= idx; i++)
   {
      double h = iHigh(_Symbol, PERIOD_M15, i);
      double l = iLow(_Symbol, PERIOD_M15, i);
      if(h > dayHi) dayHi = h;
      if(l < dayLo) dayLo = l;
   }
   if(al > 0 && dayLo < al) alSwept = true;
   if(ah > 0 && dayHi > ah) ahSwept = true;
   if(pdh > 0 && dayHi > pdh) pdhSwept = true;
   if(pdl > 0 && dayLo < pdl) pdlSwept = true;
}

string CalcMSS()
{
   double hi = -1, lo = 1e18;
   for(int i = 2; i <= MSS_Lookback + 1; i++)
   {
      double h = iHigh(_Symbol, MSS_TF, i);
      double l = iLow(_Symbol, MSS_TF, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
   }
   double c1 = iClose(_Symbol, MSS_TF, 1);
   if(c1 > hi) return "bullish";
   if(c1 < lo) return "bearish";
   return "none";
}

bool InNewsWindow()
{
   if(UseNewsWindow) return true;
   if(StringLen(NewsTimesCSV) == 0) return false;
   MqlDateTime s; TimeToStruct(TimeCurrent(), s);
   int nowMin = s.hour*60 + s.min;
   string parts[];
   int n = StringSplit(NewsTimesCSV, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string p = parts[i];
      int c = StringFind(p, ":");
      if(c < 0) continue;
      int hh = (int)StringToInteger(StringSubstr(p, 0, c));
      int mm = (int)StringToInteger(StringSubstr(p, c+1));
      int t = hh*60 + mm;
      if(MathAbs(nowMin - t) <= NewsPadMin) return true;
   }
   return false;
}

void WriteData()
{
   double ah, al, pdh, pdl; datetime asiaEnd;
   CalcAsia(ah, al, asiaEnd);
   CalcPrevDay(pdh, pdl);
   bool alS, ahS, pdhS, pdlS;
   CalcSweeps(ah, al, pdh, pdl, alS, ahS, pdhS, pdlS);
   string kz = CurrentKillzone();
   string mss = CalcMSS();
   bool news = InNewsWindow();
   double bid = MarketInfo(_Symbol, MODE_BID);
   int dg = (int)MarketInfo(_Symbol, MODE_DIGITS);

   string json = "{\n";
   json += "  \"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",\n";
   json += "  \"symbol\": \"" + _Symbol + "\",\n";
   json += "  \"bid\": " + DoubleToString(bid, dg) + ",\n";
   json += "  \"asia_high\": " + DoubleToString(ah, dg) + ",\n";
   json += "  \"asia_low\": " + DoubleToString(al, dg) + ",\n";
   json += "  \"pdh\": " + DoubleToString(pdh, dg) + ",\n";
   json += "  \"pdl\": " + DoubleToString(pdl, dg) + ",\n";
   json += "  \"killzone\": \"" + kz + "\",\n";
   json += "  \"asia_low_swept\": "  + (alS  ? "true":"false") + ",\n";
   json += "  \"asia_high_swept\": " + (ahS  ? "true":"false") + ",\n";
   json += "  \"pdh_swept\": "       + (pdhS ? "true":"false") + ",\n";
   json += "  \"pdl_swept\": "       + (pdlS ? "true":"false") + ",\n";
   json += "  \"mss\": \"" + mss + "\",\n";
   json += "  \"news_window\": " + (news ? "true":"false") + "\n";
   json += "}\n";

   int h = FileOpen(OutFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h != INVALID_HANDLE)
   {
      FileWriteString(h, json);
      FileClose(h);
   }
}
//+------------------------------------------------------------------+
