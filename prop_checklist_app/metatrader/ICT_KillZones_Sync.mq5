#property copyright "ICT Kill Zones"
#property version   "1.10"
#property description "ICT Kill Zones (Checklist SYNC): Asian / London / New York / London Close"
#property description "sessiyalarini chizadi VA holatni checklist dasturi uchun JSON faylga yozadi."
#property indicator_chart_window
#property indicator_plots 0

//--- market type ---------------------------------------------------------
enum ENUM_MARKET_TYPE
{
   MARKET_FOREX   = 0, // Forex
   MARKET_INDICES = 1  // Indices
};

//--- MSS/BOS yozuvi joylashuvi --------------------------------------------
enum ENUM_STRUCT_LABELPOS
{
   SLBL_BREAK       = 0, // Buzilgan nuqtada (o'ngda)
   SLBL_PIVOT       = 1, // Pivotda (chapda)
   SLBL_CHART_RIGHT = 2  // Chart o'ng chetida
};

//--- OTE qidiriladigan timeframe ------------------------------------------
enum ENUM_OTE_TF
{
   OTE_M1  = 0, // M1
   OTE_M5  = 1, // M5
   OTE_M15 = 2  // M15
};

#define SESSION_COUNT 4
#define SESS_ASIAN        0
#define SESS_LONDON       1
#define SESS_NEWYORK      2
#define SESS_LONDONCLOSE  3

//--- inputs ---------------------------------------------------------------
input group "== Bozor turi =="
input ENUM_MARKET_TYPE InpMarketType = MARKET_FOREX; // Bozor turi (Forex / Indices) - Kill Zone vaqtlari shunga qarab tanlanadi

input group "== Nyu-York vaqtiga o'tkazish =="
input int  InpBrokerGmtOffset = 2;     // Broker server vaqtining GMT dan farqi (qishki/standart, soat)
input bool InpAutoDST         = true;  // Broker EU yozgi vaqt qoidasiga ko'ra avtomatik +1 soat qo'shsin

input group "== Sessiyalarni yoqish/o'chirish =="
input bool InpShowAsian       = true;  // Asian Kill Zone (standart holatda aktiv)
input bool InpShowLondon      = false; // London Kill Zone
input bool InpShowNewYork     = false; // New York Kill Zone
input bool InpShowLondonClose = false; // London Close Kill Zone

input group "== Ko'rinish =="
input color InpAsianColor       = C'70,100,190';   // Asian chiziq/ramka rangi
input color InpLondonColor      = clrOrange;       // London chiziq/ramka rangi
input color InpNewYorkColor     = clrLimeGreen;    // New York chiziq/ramka rangi
input color InpLondonCloseColor = clrViolet;       // London Close chiziq/ramka rangi
input color InpBoxFillColor     = C'225,228,245';  // To'rtburchak fon (ichki) rangi
input int   InpLineWidth        = 2;               // HIGH/LOW chiziq qalinligi
input bool  InpShowLabels       = true;            // HIGH / LOW yozuvlarini chizish
input color InpLabelColor       = clrBlack;        // Yozuv (HIGH/LOW) rangi
input int   InpLabelFontSize    = 9;               // Yozuv shrift o'lchami

input group "== Tarix =="
input int InpHistoryDays = 5; // Nechta kunlik tarixni chizish

input group "== Alert (faqat max/min BIRINCHI marta buzilganda) =="
input bool   InpEnableBreakoutAlert = true;         // Killzona tugagach max/min buzilsa alert berilsin (bir marta)
input bool   InpEnableSoundAlert    = true;         // Ovozli signal chalinsin
input string InpBreakoutSoundFile   = "alert2.wav"; // Ovoz fayli (terminal Sounds papkasidagi)
input bool   InpEnablePopupAlert    = true;         // Ekranda popup xabar chiqsin

input group "== HIGH/LOW chiziqlari =="
input bool   InpShowLevelLines      = true;         // HIGH/LOW darajalarini chiziq bilan ko'rsatish

input group "== Market Structure (MSS + BOS) - kaskad M1->M5->M15 =="
input bool   InpEnableMSS       = true;         // MSS (Change of Character) aniqlansin
input bool   InpEnableBOS       = true;         // BOS (Break of Structure, trend davomi) aniqlansin
input bool   InpEnableMSSAlert  = true;         // MSS/BOS topilganda alert berilsin
input string InpMSSSoundFile    = "alert3.wav"; // MSS/BOS uchun ovoz (break dan farqli)

input group "== Struktura: swing diapazoni (har TF) =="
input int    InpStructMinM1     = 5;            // M1:  swing MIN barlar (har tomonda)
input int    InpStructMaxM1     = 10;           // M1:  swing MAX barlar (har tomonda)
input int    InpStructMinM5     = 5;            // M5:  swing MIN barlar (har tomonda)
input int    InpStructMaxM5     = 10;           // M5:  swing MAX barlar (har tomonda)
input int    InpStructMinM15    = 5;            // M15: swing MIN barlar (har tomonda)
input int    InpStructMaxM15    = 10;           // M15: swing MAX barlar (har tomonda)

input group "== Struktura: toxtovsiz rejim va BOS (har TF) =="
input bool   InpContM1          = false;        // M1:  toxtovsiz (ON=sweepdan keyin ko'p marta, OFF=faqat 1-MSS)
input bool   InpContM5          = false;        // M5:  toxtovsiz
input bool   InpContM15         = false;        // M15: toxtovsiz
input bool   InpBosM1           = true;         // M1:  BOS aniqlansin (toxtovsiz ON bo'lganda)
input bool   InpBosM5           = true;         // M5:  BOS aniqlansin
input bool   InpBosM15          = true;         // M15: BOS aniqlansin

input group "== Struktura: ko'rinish =="
input color           InpMSSLineColor  = clrNavy;      // MSS chiziq rangi
input ENUM_LINE_STYLE InpMSSLineStyle  = STYLE_SOLID;  // MSS chiziq stili
input color           InpMSSLabelColor = C'0,0,139';   // MSS yozuv rangi (to'q ko'k)
input color           InpBOSLineColor  = clrSlateGray; // BOS chiziq rangi
input ENUM_LINE_STYLE InpBOSLineStyle  = STYLE_DOT;    // BOS chiziq stili
input color           InpBOSLabelColor = clrSlateGray; // BOS yozuv rangi
input int             InpMSSLineWidth  = 2;            // Chiziq qalinligi (MSS/BOS)
input ENUM_STRUCT_LABELPOS InpStructLabelPos = SLBL_BREAK; // MSS/BOS yozuvi joylashuvi

input group "== OTE (Optimal Trade Entry) + Target zona =="
input bool        InpEnableOTE     = true;          // OTE + setup chizilsin
input ENUM_OTE_TF InpOTETimeframe  = OTE_M5;        // OTE qidiriladigan TF (shift shu TF da bo'ladi)
input double      InpOTEFibLow     = 0.618;         // OTE band pastki fib
input double      InpOTEFibHigh    = 0.786;         // OTE band yuqori fib
input color       InpOTEColor      = C'235,170,185'; // OTE band rangi (pushti)
input bool        InpOTEShowFib    = true;          // Fib darajalari (0/0.5/0.618/0.786/1) chizilsin
input color       InpOTEFibColor   = clrGray;       // Fib chiziqlari rangi
input bool        InpOTEShowLabel  = true;          // OTE yozuvi ko'rsatilsin
input bool        InpOTEShowTarget = true;          // Target zona (qarama-qarshi likvidlik) chizilsin
input color       InpOTETargetColor= C'150,215,180'; // Target zona rangi (yashil)

input group "== Oldingi kun HIGH/LOW (PDH/PDL) =="
input bool   InpEnablePrevDay      = true;         // Oldingi kun max/min chiziqlari
input color  InpPrevDayTermColor   = clrGray;      // Terminal-kun bo'yicha PDH/PDL rangi
input color  InpPrevDayNyColor     = clrTeal;      // Nyu-York kun bo'yicha PDH/PDL rangi
input int    InpPrevDayWidth       = 1;            // PDH/PDL chiziq qalinligi
input bool   InpEnablePrevDayAlert = true;         // PDH/PDL buzilganda alert berilsin
input string InpPrevDaySoundFile   = "alert4.wav"; // Oldingi kun darajasi uchun ovoz (barchasidan farqli)

input group "== Telegram Alert =="
input bool   InpEnableTelegram   = false; // Telegram orqali xabar yuborilsin
input string InpTelegramBotToken = "";    // Telegram Bot Token (@BotFather dan olinadi)
input string InpTelegramChatId   = "";    // Telegram Chat ID (raqam, masalan: 123456789)

//===========================================================================
//  YANGI: Checklist dasturi bilan SINXRON ishlash uchun JSON eksport
//===========================================================================
input group "== Checklist eksport (JSON) =="
input bool   InpEnableExport   = true;                 // Checklist dasturi uchun JSON yozilsin
input string InpExportFile     = "killzone_data.json"; // Fayl nomi (MQL5/Files ichida)
input int    InpExportEverySec = 2;                    // Necha soniyada bir yozilsin
input string InpNewsTimesCSV   = "";                   // Yangilik vaqtlari (SERVER vaqti), masalan "15:30,17:00"
input int    InpNewsPadMin     = 30;                   // Yangilik oldi/keyin daqiqa (news oynasi)

datetime g_lastExport = 0;

//--- session time tables (New York local time) -----------------------------
int    g_startHour[SESSION_COUNT];
int    g_startMin[SESSION_COUNT];
int    g_endHour[SESSION_COUNT];
int    g_endMin[SESSION_COUNT];
bool   g_enabled[SESSION_COUNT];
color  g_color[SESSION_COUNT];
string g_key[SESSION_COUNT]   = {"Asian","London","NewYork","LondonClose"};
string g_label[SESSION_COUNT] = {"ASIA","LONDON","NEW YORK","LONDON CLOSE"};

//--- running state per session ---------------------------------------------
bool     g_active[SESSION_COUNT];
datetime g_startTime[SESSION_COUNT];
datetime g_lastInTime[SESSION_COUNT];
double   g_high[SESSION_COUNT];
double   g_low[SESSION_COUNT];
datetime g_highTime[SESSION_COUNT];
datetime g_lowTime[SESSION_COUNT];

//--- max/min breakout watch state (active after a session closes) ----------
bool     g_watching[SESSION_COUNT];
double   g_watchHigh[SESSION_COUNT];
double   g_watchLow[SESSION_COUNT];
bool     g_highBroken[SESSION_COUNT];
bool     g_lowBroken[SESSION_COUNT];

//--- market structure (MSS) - multi timeframe (M1 / M5 / M15) ---------------
#define MSS_TF_COUNT 3
ENUM_TIMEFRAMES g_mssTF[MSS_TF_COUNT]     = {PERIOD_M1,PERIOD_M5,PERIOD_M15};
string          g_mssTFname[MSS_TF_COUNT] = {"M1","M5","M15"};

bool     g_mssDnWatch[SESSION_COUNT];              // HIGH buzildi -> bearish MSS qidirilyapti
bool     g_mssUpWatch[SESSION_COUNT];              // LOW  buzildi -> bullish MSS qidirilyapti
bool     g_mssDnDone[SESSION_COUNT][MSS_TF_COUNT]; // har TF uchun alohida tugallanish
bool     g_mssUpDone[SESSION_COUNT][MSS_TF_COUNT];
datetime g_mssDnTime[SESSION_COUNT][MSS_TF_COUNT]; // 1-MSS vaqti (keyingi TF shu vaqtdan qidiradi)
datetime g_mssUpTime[SESSION_COUNT][MSS_TF_COUNT];
datetime g_hiBreakTime[SESSION_COUNT];             // HIGH buzilgan vaqt (M1 MSS shu vaqtdan qidiriladi)
datetime g_loBreakTime[SESSION_COUNT];             // LOW  buzilgan vaqt
datetime g_structLastAlert[SESSION_COUNT][MSS_TF_COUNT]; // oxirgi ko'rilgan buzilish vaqti (1 martalik alert uchun)

int      g_sMinTf[MSS_TF_COUNT]; // har TF uchun swing MIN barlar (OnInit da)
int      g_sMaxTf[MSS_TF_COUNT]; // har TF uchun swing MAX barlar (OnInit da)
bool     g_contTf[MSS_TF_COUNT]; // har TF uchun toxtovsiz rejim (OnInit da)
bool     g_bosTf[MSS_TF_COUNT];  // har TF uchun BOS yoqilgan (OnInit da)

//--- previous day HIGH/LOW state -------------------------------------------
double   g_pdTermHi=0, g_pdTermLo=0; datetime g_pdTermStart=0; long g_pdTermDay=-1;
bool     g_pdTermHiBroken=false, g_pdTermLoBroken=false;
double   g_pdNyHi=0,   g_pdNyLo=0;   datetime g_pdNyStart=0;   long g_pdNyDay=-1;
bool     g_pdNyHiBroken=false,   g_pdNyLoBroken=false;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpMarketType == MARKET_FOREX)
   {
      g_startHour[SESS_ASIAN]=20; g_startMin[SESS_ASIAN]=0; g_endHour[SESS_ASIAN]=0;  g_endMin[SESS_ASIAN]=0;
      g_startHour[SESS_LONDON]=2; g_startMin[SESS_LONDON]=0; g_endHour[SESS_LONDON]=5; g_endMin[SESS_LONDON]=0;
      g_startHour[SESS_NEWYORK]=7; g_startMin[SESS_NEWYORK]=0; g_endHour[SESS_NEWYORK]=10; g_endMin[SESS_NEWYORK]=0;
      g_startHour[SESS_LONDONCLOSE]=10; g_startMin[SESS_LONDONCLOSE]=0; g_endHour[SESS_LONDONCLOSE]=12; g_endMin[SESS_LONDONCLOSE]=0;
   }
   else // MARKET_INDICES
   {
      g_startHour[SESS_ASIAN]=20; g_startMin[SESS_ASIAN]=0; g_endHour[SESS_ASIAN]=0;  g_endMin[SESS_ASIAN]=0;
      g_startHour[SESS_LONDON]=2; g_startMin[SESS_LONDON]=0; g_endHour[SESS_LONDON]=5; g_endMin[SESS_LONDON]=0;
      g_startHour[SESS_NEWYORK]=8; g_startMin[SESS_NEWYORK]=30; g_endHour[SESS_NEWYORK]=11; g_endMin[SESS_NEWYORK]=0;
      g_startHour[SESS_LONDONCLOSE]=13; g_startMin[SESS_LONDONCLOSE]=30; g_endHour[SESS_LONDONCLOSE]=16; g_endMin[SESS_LONDONCLOSE]=0;
   }

   g_enabled[SESS_ASIAN]       = InpShowAsian;
   g_enabled[SESS_LONDON]      = InpShowLondon;
   g_enabled[SESS_NEWYORK]     = InpShowNewYork;
   g_enabled[SESS_LONDONCLOSE] = InpShowLondonClose;

   g_color[SESS_ASIAN]       = InpAsianColor;
   g_color[SESS_LONDON]      = InpLondonColor;
   g_color[SESS_NEWYORK]     = InpNewYorkColor;
   g_color[SESS_LONDONCLOSE] = InpLondonCloseColor;

   // har TF uchun swing diapazoni + toxtovsiz/BOS sozlamalari
   int  mnArr[MSS_TF_COUNT]={InpStructMinM1,InpStructMinM5,InpStructMinM15};
   int  mxArr[MSS_TF_COUNT]={InpStructMaxM1,InpStructMaxM5,InpStructMaxM15};
   bool contArr[MSS_TF_COUNT]={InpContM1,InpContM5,InpContM15};
   bool bosArr[MSS_TF_COUNT] ={InpBosM1, InpBosM5, InpBosM15};
   for(int t=0;t<MSS_TF_COUNT;t++)
   {
      g_sMinTf[t]=(int)MathMax(1,MathMin(mnArr[t],mxArr[t]));
      g_sMaxTf[t]=(int)MathMax(g_sMinTf[t],MathMax(mnArr[t],mxArr[t]));
      g_contTf[t]=contArr[t];
      g_bosTf[t] =bosArr[t];
   }

   for(int i=0;i<SESSION_COUNT;i++)
   {
      g_active[i]=false;
      g_watching[i]=false;
      g_highBroken[i]=false;
      g_lowBroken[i]=false;
      g_mssDnWatch[i]=false;
      g_mssUpWatch[i]=false;
      g_hiBreakTime[i]=0;
      g_loBreakTime[i]=0;
      for(int t=0;t<MSS_TF_COUNT;t++)
      {
         g_mssDnDone[i][t]=false; g_mssUpDone[i][t]=false;
         g_mssDnTime[i][t]=0;     g_mssUpTime[i][t]=0;
         g_structLastAlert[i][t]=0;
      }
   }

   g_pdTermDay=-1; g_pdNyDay=-1;

   ObjectsDeleteAll(0,"ICTKZ_");
   EventSetTimer(1);          // YANGI: JSON eksportni tik bo'lmasa ham yangilab turish uchun
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();          // YANGI
   ObjectsDeleteAll(0,"ICTKZ_");
}

//+------------------------------------------------------------------+
//| YANGI: taymer orqali JSON ni yangilab turish                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpEnableExport && (TimeCurrent()-g_lastExport>=InpExportEverySec))
   {
      ExportState();
      g_lastExport=TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Nyu-York vaqtini hisoblash uchun yordamchi funksiyalar             |
//+------------------------------------------------------------------+
datetime NthSundayOfMonth(const int year,const int month,const int n)
{
   MqlDateTime s;
   s.year=year; s.mon=month; s.day=1; s.hour=0; s.min=0; s.sec=0;
   datetime first=StructToTime(s);
   MqlDateTime fs; TimeToStruct(first,fs);
   int dow=fs.day_of_week; // 0=Sunday
   int firstSunday=1+((7-dow)%7);
   s.day=firstSunday+(n-1)*7;
   return StructToTime(s);
}

datetime LastSundayOfMonth(const int year,const int month)
{
   int nm=month+1, ny=year;
   if(nm>12){ nm=1; ny++; }
   MqlDateTime nxt;
   nxt.year=ny; nxt.mon=nm; nxt.day=1; nxt.hour=0; nxt.min=0; nxt.sec=0;
   datetime nextMonthStart=StructToTime(nxt);
   datetime lastDay=nextMonthStart-86400;
   MqlDateTime ld; TimeToStruct(lastDay,ld);
   return lastDay-ld.day_of_week*86400;
}

bool IsEuDstActive(const datetime t)
{
   MqlDateTime m; TimeToStruct(t,m);
   datetime dstStart=LastSundayOfMonth(m.year,3)+1*3600;
   datetime dstEnd  =LastSundayOfMonth(m.year,10)+1*3600;
   return (t>=dstStart && t<dstEnd);
}

int NyUtcOffsetHours(const datetime utc)
{
   MqlDateTime m; TimeToStruct(utc,m);
   datetime dstStart=NthSundayOfMonth(m.year,3,2)+7*3600;  // 2:00 EST = 07:00 UTC
   datetime dstEnd  =NthSundayOfMonth(m.year,11,1)+6*3600; // 2:00 EDT = 06:00 UTC
   if(utc>=dstStart && utc<dstEnd) return -4;
   return -5;
}

datetime ServerToUtc(const datetime serverTime)
{
   int offset=InpBrokerGmtOffset;
   if(InpAutoDST)
   {
      datetime approxUtc=serverTime-offset*3600;
      if(IsEuDstActive(approxUtc)) offset+=1;
   }
   return serverTime-offset*3600;
}

datetime ServerToNewYork(const datetime serverTime)
{
   datetime utc=ServerToUtc(serverTime);
   int nyOff=NyUtcOffsetHours(utc);
   return utc+nyOff*3600;
}

int MinutesOfDay(const datetime t)
{
   MqlDateTime m; TimeToStruct(t,m);
   return m.hour*60+m.min;
}

bool IsInSession(const datetime nyBarOpen,const int idx)
{
   int periodMin=(int)(PeriodSeconds()/60);
   if(periodMin<1) periodMin=1;

   int startM=g_startHour[idx]*60+g_startMin[idx];
   int endM  =g_endHour[idx]*60+g_endMin[idx];
   int endEff=endM; if(endEff<=startM) endEff+=1440;

   int openM=MinutesOfDay(nyBarOpen);
   int oEff=openM; if(oEff<startM) oEff+=1440;
   int cEff=oEff+periodMin;              // bar yopilish vaqti (shu ramkada)

   return (oEff<endEff && cEff>startM);
}

//+------------------------------------------------------------------+
//| Chizish funksiyalari                                              |
//+------------------------------------------------------------------+
string MakeId(const datetime t)
{
   string s=TimeToString(t,TIME_DATE|TIME_MINUTES);
   StringReplace(s,".","");
   StringReplace(s," ","_");
   StringReplace(s,":","");
   return s;
}

void DrawSessionBox(const int idx,const datetime rightTime)
{
   string name="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+"_box";
   datetime t2=rightTime+PeriodSeconds();

   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE,0,g_startTime[idx],g_high[idx],t2,g_low[idx]);
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpBoxFillColor);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_FILL,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   else
   {
      ObjectSetInteger(0,name,OBJPROP_TIME,0,g_startTime[idx]);
      ObjectSetDouble (0,name,OBJPROP_PRICE,0,g_high[idx]);
      ObjectSetInteger(0,name,OBJPROP_TIME,1,t2);
      ObjectSetDouble (0,name,OBJPROP_PRICE,1,g_low[idx]);
   }
}

//+------------------------------------------------------------------+
void DrawLevel(const int idx,const bool isHigh,const double price,
               const datetime lineRight,const bool wasBroken)
{
   string base="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+(isHigh?"_hi":"_lo");
   string lname=base+"_ln";
   string tname=base+"_tx";
   datetime t1=g_startTime[idx];
   datetime t2=lineRight+PeriodSeconds();
   datetime labelT=g_lastInTime[idx]+PeriodSeconds(); // yozuv to'rtburchakning o'ng chetida turadi

   //--- chiziq ---
   if(InpShowLevelLines)
   {
      if(ObjectFind(0,lname)<0)
      {
         ObjectCreate(0,lname,OBJ_TREND,0,t1,price,t2,price);
         ObjectSetInteger(0,lname,OBJPROP_COLOR,g_color[idx]);
         ObjectSetInteger(0,lname,OBJPROP_STYLE,STYLE_SOLID);
         ObjectSetInteger(0,lname,OBJPROP_WIDTH,InpLineWidth);
         ObjectSetInteger(0,lname,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,lname,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,lname,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,lname,OBJPROP_BACK,false);
      }
      else if(!wasBroken)
      {
         ObjectSetInteger(0,lname,OBJPROP_TIME,0,t1);
         ObjectSetDouble (0,lname,OBJPROP_PRICE,0,price);
         ObjectSetInteger(0,lname,OBJPROP_TIME,1,t2);
         ObjectSetDouble (0,lname,OBJPROP_PRICE,1,price);
      }
   }

   //--- yozuv (ASIA HIGH / ASIA LOW) ---
   if(InpShowLabels)
   {
      string txt=g_label[idx]+(isHigh?" HIGH":" LOW");
      if(ObjectFind(0,tname)<0)
      {
         ObjectCreate(0,tname,OBJ_TEXT,0,labelT,price);
         ObjectSetString (0,tname,OBJPROP_TEXT,txt);
         ObjectSetString (0,tname,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,tname,OBJPROP_FONTSIZE,InpLabelFontSize);
         ObjectSetInteger(0,tname,OBJPROP_COLOR,InpLabelColor);
         ObjectSetInteger(0,tname,OBJPROP_ANCHOR,isHigh?ANCHOR_RIGHT_LOWER:ANCHOR_RIGHT_UPPER);
         ObjectSetInteger(0,tname,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,tname,OBJPROP_HIDDEN,true);
      }
      else if(!wasBroken)
      {
         ObjectSetInteger(0,tname,OBJPROP_TIME,0,labelT);
         ObjectSetDouble (0,tname,OBJPROP_PRICE,0,price);
      }
   }
}

//+------------------------------------------------------------------+
//| Alert / Telegram                                                  |
//+------------------------------------------------------------------+
string UrlEncode(const string text)
{
   string result="";
   int len=StringLen(text);
   for(int i=0;i<len;i++)
   {
      ushort ch=StringGetCharacter(text,i);
      bool unreserved=(ch>='A'&&ch<='Z')||(ch>='a'&&ch<='z')||(ch>='0'&&ch<='9')||ch=='-'||ch=='_'||ch=='.'||ch=='~';
      if(unreserved)
         result+=CharToString((uchar)ch);
      else
         result+=StringFormat("%%%02X",(int)ch);
   }
   return result;
}

void SendTelegramMessage(const string text)
{
   if(StringLen(InpTelegramBotToken)==0 || StringLen(InpTelegramChatId)==0)
   {
      Print("ICT Kill Zones: Telegram yuborilmadi - Bot Token yoki Chat ID kiritilmagan.");
      return;
   }

   string url="https://api.telegram.org/bot"+InpTelegramBotToken+"/sendMessage";
   string params="chat_id="+InpTelegramChatId+"&text="+UrlEncode(text);

   int len=StringLen(params);
   char post[];
   ArrayResize(post,len);
   for(int j=0;j<len;j++)
      post[j]=(char)StringGetCharacter(params,j);

   char result[];
   string resultHeaders;
   string headers="Content-Type: application/x-www-form-urlencoded\r\n";

   ResetLastError();
   int res=WebRequest("POST",url,headers,5000,post,result,resultHeaders);
   if(res==-1)
   {
      int err=GetLastError();
      PrintFormat("ICT Kill Zones: Telegram WebRequest xatosi (%d). Terminal sozlamalarida "+
                  "Tools -> Options -> Expert Advisors bo'limida 'https://api.telegram.org' manzilini "+
                  "WebRequest uchun ruxsat etilgan URL sifatida qo'shing.",err);
   }
}

void FireBreakoutAlert(const int idx,const bool isHigh,const datetime t,const double price)
{
   if(!InpEnableBreakoutAlert) return;

   string what=isHigh?"MAKSIMUM (yuqori) nuqta buzildi":"MINIMUM (quyi) nuqta buzildi";
   string text=StringFormat(
      "%s [%s]\n%s\n%s\nNarx: %s   Vaqt: %s",
      _Symbol,
      EnumToString((ENUM_TIMEFRAMES)Period()),
      g_label[idx],
      what,
      DoubleToString(price,_Digits),TimeToString(t,TIME_DATE|TIME_MINUTES)
   );

   if(InpEnableSoundAlert)
      PlaySound(InpBreakoutSoundFile);
   if(InpEnablePopupAlert)
      Alert(text);
   if(InpEnableTelegram)
      SendTelegramMessage(text);
}

//+------------------------------------------------------------------+
//| Market Structure (MSS) yordamchi funksiyalari                     |
//+------------------------------------------------------------------+
bool IsSwingLow(const int j,const int s,const int ratesTotal,const double &low[])
{
   if(j-s<0 || j+s>=ratesTotal) return false;
   for(int k=1;k<=s;k++)
      if(low[j]>=low[j-k] || low[j]>=low[j+k]) return false;
   return true;
}

bool IsSwingHigh(const int j,const int s,const int ratesTotal,const double &high[])
{
   if(j-s<0 || j+s>=ratesTotal) return false;
   for(int k=1;k<=s;k++)
      if(high[j]<=high[j-k] || high[j]<=high[j+k]) return false;
   return true;
}

void DrawStructLine(const int idx,const int tfIdx,const bool upBreak,const bool isMSS,
                    const datetime tPivot,const double price,const datetime tBreak)
{
   string kind = isMSS?"MSS":"BOS";
   string base="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+"_"+g_mssTFname[tfIdx]+"_"+kind+"_"+MakeId(tBreak);
   string lname=base+"_ln";
   string tname=base+"_tx";

   color           lclr   = isMSS?InpMSSLineColor:InpBOSLineColor;
   ENUM_LINE_STYLE lstyle = isMSS?InpMSSLineStyle:InpBOSLineStyle;
   color           tclr   = isMSS?InpMSSLabelColor:InpBOSLabelColor;

   //--- chiziq (pivotdan buzilgan barga) ---
   if(ObjectFind(0,lname)<0)
   {
      ObjectCreate(0,lname,OBJ_TREND,0,tPivot,price,tBreak,price);
      ObjectSetInteger(0,lname,OBJPROP_WIDTH,InpMSSLineWidth);
      ObjectSetInteger(0,lname,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,lname,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lname,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,lname,OBJPROP_BACK,false);
   }
   ObjectSetInteger(0,lname,OBJPROP_COLOR,lclr);
   ObjectSetInteger(0,lname,OBJPROP_STYLE,lstyle);
   ObjectSetInteger(0,lname,OBJPROP_TIME,0,tPivot);
   ObjectSetDouble (0,lname,OBJPROP_PRICE,0,price);
   ObjectSetInteger(0,lname,OBJPROP_TIME,1,tBreak);
   ObjectSetDouble (0,lname,OBJPROP_PRICE,1,price);

   //--- yozuv (joylashuvi inputdan tanlanadi) ---
   string txt = kind+" "+g_mssTFname[tfIdx]+(upBreak?" UP":" DN");
   datetime lblT;
   if(InpStructLabelPos==SLBL_PIVOT)            lblT=tPivot;
   else if(InpStructLabelPos==SLBL_CHART_RIGHT) lblT=TimeCurrent();
   else                                         lblT=tBreak;
   ENUM_ANCHOR_POINT anch = upBreak?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER; // UP tepada, DN pastda

   if(ObjectFind(0,tname)<0)
   {
      ObjectCreate(0,tname,OBJ_TEXT,0,lblT,price);
      ObjectSetString (0,tname,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,tname,OBJPROP_FONTSIZE,InpLabelFontSize);
      ObjectSetInteger(0,tname,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tname,OBJPROP_HIDDEN,true);
   }
   ObjectSetString (0,tname,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,tname,OBJPROP_COLOR,tclr);
   ObjectSetInteger(0,tname,OBJPROP_ANCHOR,anch);
   ObjectSetInteger(0,tname,OBJPROP_TIME,0,lblT);
   ObjectSetDouble (0,tname,OBJPROP_PRICE,0,price);
}

void FireStructAlert(const int idx,const int tfIdx,const bool upBreak,const bool isMSS,
                     const datetime t,const double price)
{
   if(!InpEnableMSSAlert) return;

   string kind = isMSS?"MSS (Change of Character)":"BOS (Break of Structure)";
   string dir  = upBreak?"UP (bullish)":"DN (bearish)";
   string text=StringFormat(
      "%s  %s %s\n%s\n%s  %s\nDaraja: %s   Vaqt: %s",
      _Symbol,
      isMSS?"MSS":"BOS",
      g_mssTFname[tfIdx],
      g_label[idx],
      kind, dir,
      DoubleToString(price,_Digits),TimeToString(t,TIME_DATE|TIME_MINUTES)
   );

   if(InpEnableSoundAlert)
      PlaySound(InpMSSSoundFile);
   if(InpEnablePopupAlert)
      Alert(text);
   if(InpEnableTelegram)
      SendTelegramMessage(text);
}

void ProcessStructure_TF(const int idx,const int tfIdx,const bool bullish,
                         const datetime sinceT,const bool allowAlerts)
{
   if(sinceT<=0) return;

   int sMin=g_sMinTf[tfIdx];
   int sMax=g_sMaxTf[tfIdx];

   MqlRates r[];
   int n=CopyRates(_Symbol,g_mssTF[tfIdx],0,2000,r);
   if(n<=2*sMax+2) return;
   ArraySetAsSeries(r,false);

   double hi[]; double lo[]; datetime tm[];
   ArrayResize(hi,n); ArrayResize(lo,n); ArrayResize(tm,n);
   for(int a=0;a<n;a++){ hi[a]=r[a].high; lo[a]=r[a].low; tm[a]=r[a].time; }

   int start=0;
   while(start<n && tm[start]<sinceT) start++;
   if(start>=n) return;

   int  trend = bullish ? -1 : +1;     // low-sweep: down (1-UP=MSS), high-sweep: up (1-DOWN=MSS)
   bool cont  = g_contTf[tfIdx];
   bool bosOn = (cont && InpEnableBOS && g_bosTf[tfIdx]); // BOS faqat toxtovsiz rejimda

   bool haveLow=false, haveHigh=false;
   double lowP=0, highP=0; datetime lowT=0, highT=0;
   datetime consLowT=0, consHighT=0; // iste'mol qilingan pivot vaqti (takrorni oldini olish)

   for(int k=start;k<n;k++)
   {
      for(int s=sMin;s<=sMax;s++)
      { int c=k-s; if(c-s<0) break;
        if(IsSwingLow(c,s,n,lo) && tm[c]>consLowT){ if(!haveLow || tm[c]>lowT){lowP=lo[c]; lowT=tm[c]; haveLow=true;} break; } }
      for(int s=sMin;s<=sMax;s++)
      { int c=k-s; if(c-s<0) break;
        if(IsSwingHigh(c,s,n,hi) && tm[c]>consHighT){ if(!haveHigh || tm[c]>highT){highP=hi[c]; highT=tm[c]; haveHigh=true;} break; } }

      // DOWN buzilish (swing LOW pastga)
      if(haveLow && lo[k]<lowP)
      {
         bool isMSS=(trend!=-1);
         trend=-1;
         datetime pT=lowT, bT=tm[k]; double pP=lowP;
         haveLow=false; consLowT=lowT; // shu low iste'mol qilindi
         if(isMSS && !bullish && !g_mssDnDone[idx][tfIdx])
         { g_mssDnDone[idx][tfIdx]=true; g_mssDnTime[idx][tfIdx]=bT; }
         bool draw = isMSS ? InpEnableMSS : bosOn;
         if(draw)
         {
            DrawStructLine(idx,tfIdx,false,isMSS,pT,pP,bT);
            if(bT>g_structLastAlert[idx][tfIdx])
            {
               if(allowAlerts) FireStructAlert(idx,tfIdx,false,isMSS,bT,pP);
               g_structLastAlert[idx][tfIdx]=bT;
            }
         }
         if(isMSS && !cont) return; // toxtovsiz emas -> 1-MSS dan keyin to'xta
      }

      // UP buzilish (swing HIGH yuqoriga)
      if(haveHigh && hi[k]>highP)
      {
         bool isMSS=(trend!=+1);
         trend=+1;
         datetime pT=highT, bT=tm[k]; double pP=highP;
         haveHigh=false; consHighT=highT;
         if(isMSS && bullish && !g_mssUpDone[idx][tfIdx])
         { g_mssUpDone[idx][tfIdx]=true; g_mssUpTime[idx][tfIdx]=bT; }
         bool draw = isMSS ? InpEnableMSS : bosOn;
         if(draw)
         {
            DrawStructLine(idx,tfIdx,true,isMSS,pT,pP,bT);
            if(bT>g_structLastAlert[idx][tfIdx])
            {
               if(allowAlerts) FireStructAlert(idx,tfIdx,true,isMSS,bT,pP);
               g_structLastAlert[idx][tfIdx]=bT;
            }
         }
         if(isMSS && !cont) return;
      }
   }
}

void CascadeMSS(const int idx,const bool bullish,const bool allowAlerts)
{
   bool watch = bullish ? g_mssUpWatch[idx] : g_mssDnWatch[idx];
   if(!watch) return;

   // 1-bosqich: M1 (break vaqtidan)
   datetime sinceM1 = bullish ? g_loBreakTime[idx] : g_hiBreakTime[idx];
   ProcessStructure_TF(idx,0,bullish,sinceM1,allowAlerts);
   if(bullish ? !g_mssUpDone[idx][0] : !g_mssDnDone[idx][0]) return; // M1 1-MSS kutilyapti

   // 2-bosqich: M5 (M1 1-MSS vaqtidan)
   datetime sinceM5 = bullish ? g_mssUpTime[idx][0] : g_mssDnTime[idx][0];
   ProcessStructure_TF(idx,1,bullish,sinceM5,allowAlerts);
   if(bullish ? !g_mssUpDone[idx][1] : !g_mssDnDone[idx][1]) return; // M5 1-MSS kutilyapti

   // 3-bosqich: M15 (M5 1-MSS vaqtidan)
   datetime sinceM15 = bullish ? g_mssUpTime[idx][1] : g_mssDnTime[idx][1];
   ProcessStructure_TF(idx,2,bullish,sinceM15,allowAlerts);
}

void ProcessAllMSS(const bool allowAlerts)
{
   if(!InpEnableMSS && !InpEnableBOS) return;
   for(int idx=0;idx<SESSION_COUNT;idx++)
   {
      if(!g_enabled[idx]) continue;
      CascadeMSS(idx,false,allowAlerts); // HIGH sweep -> bearish kaskad
      CascadeMSS(idx,true, allowAlerts); // LOW  sweep -> bullish kaskad
   }
}

//--- kichik yordamchi: to'ldirilgan to'rtburchak (zona) ---------------------
void UpsertBox(const string name,const datetime t1,const double p1,const datetime t2,const double p2,
               const color clr,const bool back)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,p1,t2,p2);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_FILL,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,back);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t1); ObjectSetDouble(0,name,OBJPROP_PRICE,0,p1);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,t2); ObjectSetDouble(0,name,OBJPROP_PRICE,1,p2);
}

//--- kichik yordamchi: gorizontal fib segment + o'ngda kichik yozuv ---------
void UpsertFibLine(const string name,const datetime t1,const datetime t2,const double price,
                   const color clr,const string lbl)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_TREND,0,t1,price,t2,price);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
   }
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t1); ObjectSetDouble(0,name,OBJPROP_PRICE,0,price);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,t2); ObjectSetDouble(0,name,OBJPROP_PRICE,1,price);

   string tn=name+"_l";
   if(ObjectFind(0,tn)<0)
   {
      ObjectCreate(0,tn,OBJ_TEXT,0,t2,price);
      ObjectSetString (0,tn,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,tn,OBJPROP_FONTSIZE,InpLabelFontSize-1);
      ObjectSetInteger(0,tn,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,tn,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tn,OBJPROP_HIDDEN,true);
   }
   ObjectSetString (0,tn,OBJPROP_TEXT,lbl);
   ObjectSetInteger(0,tn,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,tn,OBJPROP_TIME,0,t2); ObjectSetDouble(0,tn,OBJPROP_PRICE,0,price);
}

//+------------------------------------------------------------------+
void DrawOTESetup(const int idx,const bool bullish,const double sweepP,const double shiftP,
                  const datetime leftT,const double targetP)
{
   double rng = sweepP - shiftP;
   double lFibLo = shiftP + InpOTEFibLow *rng;
   double lFibHi = shiftP + InpOTEFibHigh*rng;
   double zHi=MathMax(lFibLo,lFibHi), zLo=MathMin(lFibLo,lFibHi);
   double entry=(lFibLo+lFibHi)/2.0; // OTE o'rtasi
   datetime t2=TimeCurrent();

   string base="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+"_OTE_"+(bullish?"up":"dn");

   if(InpOTEShowTarget)
      UpsertBox(base+"_tgt",leftT,entry,t2,targetP,InpOTETargetColor,true);

   UpsertBox(base+"_ote",leftT,zHi,t2,zLo,InpOTEColor,true);

   if(InpOTEShowFib)
   {
      UpsertFibLine(base+"_f0",  leftT,t2, shiftP,            InpOTEFibColor, "0");
      UpsertFibLine(base+"_f50", leftT,t2, shiftP+0.5*rng,    InpOTEFibColor, "0.5");
      UpsertFibLine(base+"_f62", leftT,t2, lFibLo,            InpOTEFibColor, DoubleToString(InpOTEFibLow,3));
      UpsertFibLine(base+"_f78", leftT,t2, lFibHi,            InpOTEFibColor, DoubleToString(InpOTEFibHigh,3));
      UpsertFibLine(base+"_f100",leftT,t2, sweepP,            InpOTEFibColor, "1");
   }

   if(InpOTEShowLabel)
   {
      string tname=base+"_tx";
      double mid=(zHi+zLo)/2.0;
      if(ObjectFind(0,tname)<0)
      {
         ObjectCreate(0,tname,OBJ_TEXT,0,t2,mid);
         ObjectSetString (0,tname,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,tname,OBJPROP_FONTSIZE,InpLabelFontSize);
         ObjectSetInteger(0,tname,OBJPROP_ANCHOR,ANCHOR_RIGHT);
         ObjectSetInteger(0,tname,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,tname,OBJPROP_HIDDEN,true);
      }
      ObjectSetString (0,tname,OBJPROP_TEXT,"OTE "+g_mssTFname[(int)InpOTETimeframe]);
      ObjectSetInteger(0,tname,OBJPROP_COLOR,InpOTEColor);
      ObjectSetInteger(0,tname,OBJPROP_TIME,0,t2);
      ObjectSetDouble (0,tname,OBJPROP_PRICE,0,mid);
   }
}

void ProcessOTE(const int idx)
{
   if(!InpEnableOTE) return;
   int tf=(int)InpOTETimeframe;

   bool bull = g_mssUpWatch[idx] && g_mssUpDone[idx][tf]; // LOW sweep + UP shift
   bool bear = g_mssDnWatch[idx] && g_mssDnDone[idx][tf]; // HIGH sweep + DOWN shift
   if(!bull && !bear) return;

   MqlRates r[];
   int n=CopyRates(_Symbol,g_mssTF[tf],0,2000,r);
   if(n<=2) return;
   ArraySetAsSeries(r,false);

   if(bull)
   {
      datetime t0=g_loBreakTime[idx], tMss=g_mssUpTime[idx][tf];
      double sweepLow=DBL_MAX; datetime sweepT=t0;
      for(int a=0;a<n;a++)
      {
         if(r[a].time<t0) continue;
         if(r[a].time>tMss) break;
         if(r[a].low<sweepLow){ sweepLow=r[a].low; sweepT=r[a].time; }
      }
      if(sweepLow==DBL_MAX) return;
      double impHigh=-DBL_MAX;
      for(int a=0;a<n;a++){ if(r[a].time<sweepT) continue; if(r[a].high>impHigh) impHigh=r[a].high; }
      if(impHigh==-DBL_MAX) return;
      DrawOTESetup(idx,true,sweepLow,impHigh,sweepT,g_watchHigh[idx]);
   }

   if(bear)
   {
      datetime t0=g_hiBreakTime[idx], tMss=g_mssDnTime[idx][tf];
      double sweepHigh=-DBL_MAX; datetime sweepT=t0;
      for(int a=0;a<n;a++)
      {
         if(r[a].time<t0) continue;
         if(r[a].time>tMss) break;
         if(r[a].high>sweepHigh){ sweepHigh=r[a].high; sweepT=r[a].time; }
      }
      if(sweepHigh==-DBL_MAX) return;
      double impLow=DBL_MAX;
      for(int a=0;a<n;a++){ if(r[a].time<sweepT) continue; if(r[a].low<impLow) impLow=r[a].low; }
      if(impLow==DBL_MAX) return;
      DrawOTESetup(idx,false,sweepHigh,impLow,sweepT,g_watchLow[idx]);
   }
}

void ProcessAllOTE()
{
   if(!InpEnableOTE) return;
   for(int idx=0;idx<SESSION_COUNT;idx++)
   {
      if(!g_enabled[idx]) continue;
      ProcessOTE(idx);
   }
}

//+------------------------------------------------------------------+
void ProcessSession(const int idx,const int scanStart,const int ratesTotal,
                     const datetime &time[],const double &high[],const double &low[],
                     const bool allowAlerts)
{
   if(!g_enabled[idx]) return;

   for(int i=scanStart;i<ratesTotal;i++)
   {
      datetime nyTime=ServerToNewYork(time[i]);
      bool inWin=IsInSession(nyTime,idx);

      if(inWin)
      {
         if(!g_active[idx])
         {
            g_watching[idx]=false;
            g_mssDnWatch[idx]=false; g_mssUpWatch[idx]=false;
            g_hiBreakTime[idx]=0; g_loBreakTime[idx]=0;
            for(int t=0;t<MSS_TF_COUNT;t++)
            {
               g_mssDnDone[idx][t]=false; g_mssUpDone[idx][t]=false;
               g_mssDnTime[idx][t]=0;     g_mssUpTime[idx][t]=0;
               g_structLastAlert[idx][t]=0;
            }
            g_active[idx]=true;
            g_startTime[idx]=time[i];
            g_high[idx]=high[i];
            g_low[idx]=low[i];
            g_highTime[idx]=time[i];
            g_lowTime[idx]=time[i];
         }
         else
         {
            if(high[i]>g_high[idx]){ g_high[idx]=high[i]; g_highTime[idx]=time[i]; }
            if(low[i]<g_low[idx]) { g_low[idx]=low[i];   g_lowTime[idx]=time[i]; }
         }
         g_lastInTime[idx]=time[i];

         DrawSessionBox(idx,g_lastInTime[idx]);
         DrawLevel(idx,true,g_high[idx],g_lastInTime[idx],false);
         DrawLevel(idx,false,g_low[idx],g_lastInTime[idx],false);
      }
      else
      {
         if(g_active[idx])
         {
            g_active[idx]=false;
            g_watching[idx]=true;
            g_watchHigh[idx]=g_high[idx];
            g_watchLow[idx]=g_low[idx];
            g_highBroken[idx]=false;
            g_lowBroken[idx]=false;
         }
      }

      if(g_watching[idx])
      {
         bool hiWasBroken=g_highBroken[idx];
         bool loWasBroken=g_lowBroken[idx];

         if(!g_highBroken[idx] && high[i]>g_watchHigh[idx])
         {
            g_highBroken[idx]=true;
            g_mssDnWatch[idx]=true; g_hiBreakTime[idx]=time[i];
            for(int t=0;t<MSS_TF_COUNT;t++){ g_mssDnDone[idx][t]=false; g_mssDnTime[idx][t]=0; g_structLastAlert[idx][t]=0; }
            if(allowAlerts)
               FireBreakoutAlert(idx,true,time[i],high[i]);
         }
         if(!g_lowBroken[idx] && low[i]<g_watchLow[idx])
         {
            g_lowBroken[idx]=true;
            g_mssUpWatch[idx]=true; g_loBreakTime[idx]=time[i];
            for(int t=0;t<MSS_TF_COUNT;t++){ g_mssUpDone[idx][t]=false; g_mssUpTime[idx][t]=0; g_structLastAlert[idx][t]=0; }
            if(allowAlerts)
               FireBreakoutAlert(idx,false,time[i],low[i]);
         }

         DrawLevel(idx,true,g_watchHigh[idx],time[i],hiWasBroken);
         DrawLevel(idx,false,g_watchLow[idx],time[i],loWasBroken);
      }
   }
}

//+------------------------------------------------------------------+
void DrawPrevDayLine(const string id,const bool isHigh,const double price,
                     const datetime startT,const color clr,const string labelTxt)
{
   string lname="ICTKZ_PD_"+id+(isHigh?"_hi":"_lo")+"_ln";
   string tname="ICTKZ_PD_"+id+(isHigh?"_hi":"_lo")+"_tx";

   if(ObjectFind(0,lname)<0)
   {
      ObjectCreate(0,lname,OBJ_TREND,0,startT,price,TimeCurrent(),price);
      ObjectSetInteger(0,lname,OBJPROP_STYLE,STYLE_DASHDOT);
      ObjectSetInteger(0,lname,OBJPROP_WIDTH,InpPrevDayWidth);
      ObjectSetInteger(0,lname,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,lname,OBJPROP_RAY_RIGHT,true);
      ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lname,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,lname,OBJPROP_BACK,false);
   }
   ObjectSetInteger(0,lname,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,lname,OBJPROP_TIME,0,startT);
   ObjectSetDouble (0,lname,OBJPROP_PRICE,0,price);
   ObjectSetInteger(0,lname,OBJPROP_TIME,1,TimeCurrent());
   ObjectSetDouble (0,lname,OBJPROP_PRICE,1,price);

   datetime lblT=TimeCurrent();
   if(ObjectFind(0,tname)<0)
   {
      ObjectCreate(0,tname,OBJ_TEXT,0,lblT,price);
      ObjectSetString (0,tname,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,tname,OBJPROP_FONTSIZE,InpLabelFontSize);
      ObjectSetInteger(0,tname,OBJPROP_ANCHOR,isHigh?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,tname,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tname,OBJPROP_HIDDEN,true);
   }
   ObjectSetString (0,tname,OBJPROP_TEXT,labelTxt);
   ObjectSetInteger(0,tname,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,tname,OBJPROP_ANCHOR,isHigh?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,tname,OBJPROP_TIME,0,lblT);
   ObjectSetDouble (0,tname,OBJPROP_PRICE,0,price);
}

void FirePrevDayAlert(const string zoneName,const bool isHigh,const double price)
{
   if(!InpEnablePrevDayAlert) return;
   string text=StringFormat("%s [%s]\nOldingi kun %s (%s) buzildi\nDaraja: %s",
      _Symbol,EnumToString((ENUM_TIMEFRAMES)Period()),
      isHigh?"HIGH":"LOW", zoneName,
      DoubleToString(price,_Digits));
   if(InpEnableSoundAlert)
      PlaySound(InpPrevDaySoundFile);
   if(InpEnablePopupAlert)
      Alert(text);
   if(InpEnableTelegram)
      SendTelegramMessage(text);
}

void ProcessPrevDay(const int ratesTotal,const datetime &time[],
                    const double &high[],const double &low[],const double &close[],
                    const bool useNy,const bool allowAlerts)
{
   if(ratesTotal<2) return;

   long shift = useNy ? (long)17*3600 : 0; // ICT: kun 17:00 NY da boshlanadi

   datetime nowT=time[ratesTotal-1];
   datetime nowRef = useNy ? ServerToNewYork(nowT) : nowT;
   long todayIdx=(long)(((long)nowRef - shift)/86400); // joriy savdo kuni

   long prevIdx=0; bool havePrev=false;
   for(int b=ratesTotal-1;b>=0;b--)
   {
      datetime tb = useNy ? ServerToNewYork(time[b]) : time[b];
      long idx=(long)(((long)tb - shift)/86400);
      if(idx<todayIdx){ prevIdx=idx; havePrev=true; break; }
   }
   if(!havePrev) return;

   double hi=-DBL_MAX, lo=DBL_MAX; datetime firstT=0; bool found=false;
   for(int b=ratesTotal-1;b>=0;b--)
   {
      datetime tb = useNy ? ServerToNewYork(time[b]) : time[b];
      long idx=(long)(((long)tb - shift)/86400);
      if(idx==prevIdx)
      {
         if(high[b]>hi) hi=high[b];
         if(low[b]<lo)  lo=low[b];
         firstT=time[b];
         found=true;
      }
      else if(idx<prevIdx)
         break;
   }
   if(!found) return;

   string id     = useNy ? "NY"   : "TERM";
   string zone   = useNy ? "NY"   : "Terminal";
   color  clr    = useNy ? InpPrevDayNyColor : InpPrevDayTermColor;
   string hiLbl  = useNy ? "PDH (NY)" : "PDH";
   string loLbl  = useNy ? "PDL (NY)" : "PDL";

   long   prevDay   = useNy ? g_pdNyDay : g_pdTermDay;
   bool   hiBroken  = useNy ? g_pdNyHiBroken : g_pdTermHiBroken;
   bool   loBroken  = useNy ? g_pdNyLoBroken : g_pdTermLoBroken;

   if(prevDay!=prevIdx)
   {
      hiBroken = (high[ratesTotal-1] > hi);
      loBroken = (low[ratesTotal-1]  < lo);
      prevDay=prevIdx;
   }

   DrawPrevDayLine(id,true, hi,firstT,clr,hiLbl);
   DrawPrevDayLine(id,false,lo,firstT,clr,loLbl);

   if(!hiBroken && high[ratesTotal-1]>hi)
   {
      hiBroken=true;
      if(allowAlerts) FirePrevDayAlert(zone,true,hi);
   }
   if(!loBroken && low[ratesTotal-1]<lo)
   {
      loBroken=true;
      if(allowAlerts) FirePrevDayAlert(zone,false,lo);
   }

   if(useNy)
   {
      g_pdNyHi=hi; g_pdNyLo=lo; g_pdNyStart=firstT; g_pdNyDay=prevDay;
      g_pdNyHiBroken=hiBroken; g_pdNyLoBroken=loBroken;
   }
   else
   {
      g_pdTermHi=hi; g_pdTermLo=lo; g_pdTermStart=firstT; g_pdTermDay=prevDay;
      g_pdTermHiBroken=hiBroken; g_pdTermLoBroken=loBroken;
   }
}

//===========================================================================
//  YANGI: Checklist bilan SINXRON — holatni JSON faylga yozish
//===========================================================================
bool InNewsWindow2()
{
   if(StringLen(InpNewsTimesCSV)==0) return false;
   MqlDateTime s; TimeToStruct(TimeCurrent(),s);
   int nowMin=s.hour*60+s.min;
   string parts[];
   int n=StringSplit(InpNewsTimesCSV,',',parts);
   for(int i=0;i<n;i++)
   {
      string p=parts[i];
      int c=StringFind(p,":");
      if(c<0) continue;
      int hh=(int)StringToInteger(StringSubstr(p,0,c));
      int mm=(int)StringToInteger(StringSubstr(p,c+1));
      if(MathAbs(nowMin-(hh*60+mm))<=InpNewsPadMin) return true;
   }
   return false;
}

// Indikatorning JONLI holatini (killzone/sweep/MSS/PDH-PDL) checklist
// dasturi o'qiydigan JSON faylga yozadi. Bu indikatorning o'z ichki
// hisob-kitobi bo'lgani uchun checklist AYNAN ekranda ko'rinayotgan
// setup bilan sinxron ishlaydi.
void ExportState()
{
   if(!InpEnableExport) return;

   // 1) Joriy killzone (aktiv sessiya)
   string kz="None";
   for(int i=0;i<SESSION_COUNT;i++)
      if(g_enabled[i] && g_active[i]){ kz=g_key[i]; break; }

   // 2) Asia darajalari va sweep holati
   int a=SESS_ASIAN;
   double asiaHi = g_watching[a] ? g_watchHigh[a] : g_high[a];
   double asiaLo = g_watching[a] ? g_watchLow[a]  : g_low[a];
   bool asiaHiSwept = g_highBroken[a];
   bool asiaLoSwept = g_lowBroken[a];

   // 3) PDH/PDL (terminal-kun ustuvor, bo'lmasa NY-kun)
   double pdh = (g_pdTermHi>0) ? g_pdTermHi : g_pdNyHi;
   double pdl = (g_pdTermLo>0) ? g_pdTermLo : g_pdNyLo;
   bool pdhSwept = g_pdTermHiBroken || g_pdNyHiBroken;
   bool pdlSwept = g_pdTermLoBroken || g_pdNyLoBroken;

   // 4) MSS — OTE timeframe bo'yicha tasdiqlangan shift (aynan OTE chizilgan payt)
   int otf=(int)InpOTETimeframe;
   string mss="none";
   for(int i=0;i<SESSION_COUNT;i++)
   {
      if(!g_enabled[i]) continue;
      if(g_mssUpWatch[i] && g_mssUpDone[i][otf]) { mss="bullish"; break; }
      if(g_mssDnWatch[i] && g_mssDnDone[i][otf]) { mss="bearish"; break; }
   }

   // 5) OTE setup tayyor bo'lganini ham beramiz (qo'shimcha ma'lumot)
   bool oteReady=false;
   for(int i=0;i<SESSION_COUNT;i++)
   {
      if(!g_enabled[i]) continue;
      if((g_mssUpWatch[i] && g_mssUpDone[i][otf]) ||
         (g_mssDnWatch[i] && g_mssDnDone[i][otf])) { oteReady=true; break; }
   }

   bool news=InNewsWindow2();
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int dg=_Digits;

   string j="{\n";
   j+="  \"timestamp\": \""+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+"\",\n";
   j+="  \"symbol\": \""+_Symbol+"\",\n";
   j+="  \"bid\": "+DoubleToString(bid,dg)+",\n";
   j+="  \"killzone\": \""+kz+"\",\n";
   j+="  \"asia_high\": "+DoubleToString(asiaHi,dg)+",\n";
   j+="  \"asia_low\": "+DoubleToString(asiaLo,dg)+",\n";
   j+="  \"pdh\": "+DoubleToString(pdh,dg)+",\n";
   j+="  \"pdl\": "+DoubleToString(pdl,dg)+",\n";
   j+="  \"asia_high_swept\": "+(asiaHiSwept?"true":"false")+",\n";
   j+="  \"asia_low_swept\": "+(asiaLoSwept?"true":"false")+",\n";
   j+="  \"pdh_swept\": "+(pdhSwept?"true":"false")+",\n";
   j+="  \"pdl_swept\": "+(pdlSwept?"true":"false")+",\n";
   j+="  \"mss\": \""+mss+"\",\n";
   j+="  \"ote_ready\": "+(oteReady?"true":"false")+",\n";
   j+="  \"news_window\": "+(news?"true":"false")+"\n";
   j+="}\n";

   int h=FileOpen(InpExportFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h!=INVALID_HANDLE)
   {
      FileWriteString(h,j);
      FileClose(h);
   }
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
   if(rates_total<=0) return(0);

   int scanStart;
   if(prev_calculated<=0)
   {
      for(int i=0;i<SESSION_COUNT;i++)
      {
         g_active[i]=false;
         g_watching[i]=false;
         g_highBroken[i]=false;
         g_lowBroken[i]=false;
         g_mssDnWatch[i]=false;
         g_mssUpWatch[i]=false;
         g_hiBreakTime[i]=0;
         g_loBreakTime[i]=0;
         for(int t=0;t<MSS_TF_COUNT;t++)
         {
            g_mssDnDone[i][t]=false; g_mssUpDone[i][t]=false;
            g_mssDnTime[i][t]=0;     g_mssUpTime[i][t]=0;
            g_structLastAlert[i][t]=0;
         }
      }
      g_pdTermDay=-1; g_pdNyDay=-1;

      int periodSec=PeriodSeconds();
      int barsPerDay=(periodSec>0)?(int)MathMax(1,86400/periodSec):1;
      int lookbackBars=barsPerDay*InpHistoryDays+50;
      scanStart=(int)MathMax(0,rates_total-lookbackBars);
   }
   else
   {
      scanStart=(int)MathMax(0,prev_calculated-2);
   }

   bool allowAlerts=(prev_calculated>0);
   for(int idx=0; idx<SESSION_COUNT; idx++)
      ProcessSession(idx,scanStart,rates_total,time,high,low,allowAlerts);

   ProcessAllMSS(allowAlerts);
   ProcessAllOTE();

   if(InpEnablePrevDay)
   {
      ProcessPrevDay(rates_total,time,high,low,close,false,allowAlerts); // terminal
      ProcessPrevDay(rates_total,time,high,low,close,true, allowAlerts); // Nyu-York
   }

   // YANGI: har hisobdan keyin checklist uchun JSON holatni yangilaymiz
   if(InpEnableExport)
   {
      ExportState();
      g_lastExport=TimeCurrent();
   }

   return(rates_total);
}
