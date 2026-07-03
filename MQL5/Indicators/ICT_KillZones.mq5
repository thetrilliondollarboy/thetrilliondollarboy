#property copyright "ICT Kill Zones"
#property version   "1.00"
#property description "ICT Kill Zones: Asian / London / New York / London Close sessiyalarini"
#property description "Nyu-York vaqtiga moslab, sessiya oralig'ini to'rtburchak va"
#property description "sessiyadagi maksimum/minimum nuqtalarni chizadi."
#property indicator_chart_window
#property indicator_plots 0

//--- market type ---------------------------------------------------------
enum ENUM_MARKET_TYPE
{
   MARKET_FOREX   = 0, // Forex
   MARKET_INDICES = 1  // Indices
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

input group "== Market Structure (MSS) - break dan keyin =="
input bool   InpEnableMSS       = true;         // Break dan keyin market structure (MSS) qidirilsin
input int    InpStructBarsMin   = 5;            // Swing aniqlash - MIN barlar (har tomonda)
input int    InpStructBarsMax   = 10;           // Swing aniqlash - MAX barlar (har tomonda)
input color  InpMSSColorM1      = clrDeepPink;  // MSS M1 rangi
input color  InpMSSColorM5      = clrOrange;    // MSS M5 rangi
input color  InpMSSColorM15     = clrAqua;      // MSS M15 rangi
input int    InpMSSLineWidth    = 1;            // MSS chizig'i qalinligi
input int    InpMSSLabelGap     = 40;           // TF yozuvlari orasidagi vertikal masofa (punkt)
input bool   InpEnableMSSAlert  = true;         // MSS topilganda alert berilsin
input string InpMSSSoundFile    = "alert3.wav"; // MSS uchun alohida ovoz (break dan farqli)

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
datetime g_hiBreakTime[SESSION_COUNT];             // HIGH buzilgan vaqt (MSS shu vaqtdan qidiriladi)
datetime g_loBreakTime[SESSION_COUNT];             // LOW  buzilgan vaqt

color           g_mssColor[MSS_TF_COUNT];          // har TF uchun rang (OnInit da)
ENUM_LINE_STYLE g_mssStyle[MSS_TF_COUNT] = {STYLE_DOT,STYLE_DASH,STYLE_SOLID}; // M1/M5/M15

int      g_sMin=5;  // swing strength (har tomonda min barlar) - OnInit da to'g'rilanadi
int      g_sMax=10; // swing strength (har tomonda max barlar)

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

   // swing strength diapazonini to'g'rilash (min<=max, >=1)
   g_sMin=(int)MathMax(1,MathMin(InpStructBarsMin,InpStructBarsMax));
   g_sMax=(int)MathMax(g_sMin,MathMax(InpStructBarsMin,InpStructBarsMax));

   g_mssColor[0]=InpMSSColorM1;
   g_mssColor[1]=InpMSSColorM5;
   g_mssColor[2]=InpMSSColorM15;

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
      for(int t=0;t<MSS_TF_COUNT;t++){ g_mssDnDone[i][t]=false; g_mssUpDone[i][t]=false; }
   }

   g_pdTermDay=-1; g_pdNyDay=-1;

   ObjectsDeleteAll(0,"ICTKZ_");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,"ICTKZ_");
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
   // Bar OCHILISH vaqti bilan emas, butun bar oralig'i [ochilish, yopilish)
   // sessiya oralig'i bilan kesishishi bo'yicha tekshiramiz. Shunda sessiya
   // oxiridagi oxirgi bar (masalan 6:55->7:00) ham to'liq hisobga olinadi.
   int periodMin=(int)(PeriodSeconds()/60);
   if(periodMin<1) periodMin=1;

   int startM=g_startHour[idx]*60+g_startMin[idx];
   int endM  =g_endHour[idx]*60+g_endMin[idx];
   int endEff=endM; if(endEff<=startM) endEff+=1440;

   int openM=MinutesOfDay(nyBarOpen);
   int oEff=openM; if(oEff<startM) oEff+=1440;
   int cEff=oEff+periodMin;              // bar yopilish vaqti (shu ramkada)

   // bar [oEff, cEff) va sessiya [startM, endEff) kesishsa - bar sessiya ichida
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
//| HIGH yoki LOW darajasi: chiziq (to'rtburchak boshidan o'ngga) +   |
//| ustiga "ASIA HIGH" / "ASIA LOW" ko'rinishidagi yozuv              |
//| lineRight - chiziq o'ng cheti; wasBroken - shu bardan oldin       |
//| buzilgan bo'lsa chiziq cho'zilmaydi (buzilgan joyda uziladi)      |
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
         // HIGH yozuvi chiziq tepasida, LOW yozuvi chiziq pastida
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

void DrawMSSLine(const int idx,const int tfIdx,const bool bullish,const datetime tPivot,
                 const double price,const datetime rightTime,const bool finalBroken)
{
   string base="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+"_"+g_mssTFname[tfIdx]+(bullish?"_mssUp":"_mssDn");
   string lname=base+"_ln";
   string tname=base+"_tx";
   datetime t2=rightTime;
   color clr=g_mssColor[tfIdx];

   if(ObjectFind(0,lname)<0)
   {
      ObjectCreate(0,lname,OBJ_TREND,0,tPivot,price,t2,price);
      ObjectSetInteger(0,lname,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,lname,OBJPROP_STYLE,g_mssStyle[tfIdx]);
      ObjectSetInteger(0,lname,OBJPROP_WIDTH,InpMSSLineWidth);
      ObjectSetInteger(0,lname,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,lname,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lname,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,lname,OBJPROP_BACK,false);
   }
   else
   {
      ObjectSetInteger(0,lname,OBJPROP_TIME,0,tPivot);
      ObjectSetDouble (0,lname,OBJPROP_PRICE,0,price);
      ObjectSetInteger(0,lname,OBJPROP_TIME,1,t2);
      ObjectSetDouble (0,lname,OBJPROP_PRICE,1,price);
   }

   // buzilganda: chiziq qalinlashadi va "MSS <TF>" yozuvi qo'yiladi.
   // yozuvlar bir-biriga yopishmasligi uchun har TF vertikal ravishda suriladi.
   if(finalBroken)
   {
      ObjectSetInteger(0,lname,OBJPROP_WIDTH,InpMSSLineWidth+1);
      string txt="MSS "+g_mssTFname[tfIdx]+(bullish?" UP":" DN");
      double gap=(tfIdx+1)*InpMSSLabelGap*_Point;
      double lblPrice = bullish ? price+gap : price-gap;
      if(ObjectFind(0,tname)<0)
      {
         ObjectCreate(0,tname,OBJ_TEXT,0,t2,lblPrice);
         ObjectSetString (0,tname,OBJPROP_TEXT,txt);
         ObjectSetString (0,tname,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,tname,OBJPROP_FONTSIZE,InpLabelFontSize);
         ObjectSetInteger(0,tname,OBJPROP_COLOR,clr);
         // UP yozuvi chiziq tepasida, DN yozuvi chiziq pastida
         ObjectSetInteger(0,tname,OBJPROP_ANCHOR,bullish?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0,tname,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,tname,OBJPROP_HIDDEN,true);
      }
      else
      {
         ObjectSetInteger(0,tname,OBJPROP_TIME,0,t2);
         ObjectSetDouble (0,tname,OBJPROP_PRICE,0,lblPrice);
      }
   }
}

void FireMSSAlert(const int idx,const int tfIdx,const bool bullish,const datetime t,const double price)
{
   if(!InpEnableMSSAlert) return;

   string dir=bullish?"BULLISH Market Structure Shift":"BEARISH Market Structure Shift";
   string text=StringFormat(
      "%s  MSS %s\n%s\n%s\nDaraja: %s   Vaqt: %s",
      _Symbol,
      g_mssTFname[tfIdx],
      g_label[idx],
      dir,
      DoubleToString(price,_Digits),TimeToString(t,TIME_DATE|TIME_MINUTES)
   );

   if(InpEnableSoundAlert)
      PlaySound(InpMSSSoundFile);
   if(InpEnablePopupAlert)
      Alert(text);
   if(InpEnableTelegram)
      SendTelegramMessage(text);
}

// Bitta timeframe uchun: break vaqtidan keyin market structure shift qidirish.
// bullish=false -> HIGH sweep bo'lgan, swing LOW pastga buzilishini kutamiz (bearish MSS)
// bullish=true  -> LOW sweep bo'lgan, swing HIGH yuqoriga buzilishini kutamiz (bullish MSS)
void ProcessMSS_TF(const int idx,const int tfIdx,const bool bullish,const bool allowAlerts)
{
   if(bullish){ if(!g_mssUpWatch[idx] || g_mssUpDone[idx][tfIdx]) return; }
   else       { if(!g_mssDnWatch[idx] || g_mssDnDone[idx][tfIdx]) return; }

   datetime sinceT = bullish ? g_loBreakTime[idx] : g_hiBreakTime[idx];
   if(sinceT<=0) return;

   MqlRates r[];
   int n=CopyRates(_Symbol,g_mssTF[tfIdx],0,2000,r);
   if(n<=2*g_sMax+2) return;
   ArraySetAsSeries(r,false); // eng eski birinchi

   double hi[]; double lo[]; datetime tm[];
   ArrayResize(hi,n); ArrayResize(lo,n); ArrayResize(tm,n);
   for(int a=0;a<n;a++){ hi[a]=r[a].high; lo[a]=r[a].low; tm[a]=r[a].time; }

   int start=0;
   while(start<n && tm[start]<sinceT) start++;
   if(start>=n) return;

   bool have=false;
   double pivPrice=0; datetime pivTime=0;

   for(int k=start;k<n;k++)
   {
      // 1) buzilishni tekshiramiz (kuzatilayotgan pivot mavjud bo'lsa)
      if(have)
      {
         if(!bullish && lo[k]<pivPrice) // bearish MSS
         {
            DrawMSSLine(idx,tfIdx,false,pivTime,pivPrice,tm[k],true);
            g_mssDnDone[idx][tfIdx]=true;
            if(allowAlerts) FireMSSAlert(idx,tfIdx,false,tm[k],pivPrice);
            return;
         }
         if(bullish && hi[k]>pivPrice)  // bullish MSS
         {
            DrawMSSLine(idx,tfIdx,true,pivTime,pivPrice,tm[k],true);
            g_mssUpDone[idx][tfIdx]=true;
            if(allowAlerts) FireMSSAlert(idx,tfIdx,true,tm[k],pivPrice);
            return;
         }
      }

      // 2) eng oxirgi tasdiqlangan swing ni yangilaymiz (g_sMin dan g_sMax gacha)
      for(int s=g_sMin;s<=g_sMax;s++)
      {
         int c=k-s;
         if(c-s<0) break;
         if(!bullish)
         {
            if(IsSwingLow(c,s,n,lo)){ pivPrice=lo[c]; pivTime=tm[c]; have=true; break; }
         }
         else
         {
            if(IsSwingHigh(c,s,n,hi)){ pivPrice=hi[c]; pivTime=tm[c]; have=true; break; }
         }
      }
   }

   // hali buzilmadi - kutilayotgan pivot chizig'ini oxirgi barga cho'zamiz
   if(have)
      DrawMSSLine(idx,tfIdx,bullish,pivTime,pivPrice,tm[n-1],false);
}

// barcha kuzatilayotgan sessiyalar uchun M1/M5/M15 da MSS qidirish
void ProcessAllMSS(const bool allowAlerts)
{
   if(!InpEnableMSS) return;
   for(int idx=0;idx<SESSION_COUNT;idx++)
   {
      if(!g_enabled[idx]) continue;
      for(int t=0;t<MSS_TF_COUNT;t++)
      {
         if(g_mssDnWatch[idx]) ProcessMSS_TF(idx,t,false,allowAlerts);
         if(g_mssUpWatch[idx]) ProcessMSS_TF(idx,t,true, allowAlerts);
      }
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
            // yangi sessiya boshlandi - eski kuzatuvlar to'xtaydi
            g_watching[idx]=false;
            g_mssDnWatch[idx]=false; g_mssUpWatch[idx]=false;
            g_hiBreakTime[idx]=0; g_loBreakTime[idx]=0;
            for(int t=0;t<MSS_TF_COUNT;t++){ g_mssDnDone[idx][t]=false; g_mssUpDone[idx][t]=false; }
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

         // sessiya davomida: to'rtburchak + HIGH/LOW chiziq va yozuvlar
         DrawSessionBox(idx,g_lastInTime[idx]);
         DrawLevel(idx,true,g_high[idx],g_lastInTime[idx],false);
         DrawLevel(idx,false,g_low[idx],g_lastInTime[idx],false);
      }
      else
      {
         if(g_active[idx])
         {
            g_active[idx]=false;

            // killzona TO'LIQ tugadi - endi max/min nuqtalar buzilishini kuzatamiz
            // (sessiya tugashining o'zida alert berilmaydi, faqat buzilishda)
            g_watching[idx]=true;
            g_watchHigh[idx]=g_high[idx];
            g_watchLow[idx]=g_low[idx];
            g_highBroken[idx]=false;
            g_lowBroken[idx]=false;
         }
      }

      if(g_watching[idx])
      {
         // shu bardan oldingi buzilish holati (chiziqni buzilgan joyda uzish uchun)
         bool hiWasBroken=g_highBroken[idx];
         bool loWasBroken=g_lowBroken[idx];

         if(!g_highBroken[idx] && high[i]>g_watchHigh[idx])
         {
            g_highBroken[idx]=true;
            // HIGH buzildi -> bearish MSS qidirishni boshlaymiz (barcha TF)
            g_mssDnWatch[idx]=true; g_hiBreakTime[idx]=time[i];
            for(int t=0;t<MSS_TF_COUNT;t++) g_mssDnDone[idx][t]=false;
            if(allowAlerts)
               FireBreakoutAlert(idx,true,time[i],high[i]);
         }
         if(!g_lowBroken[idx] && low[i]<g_watchLow[idx])
         {
            g_lowBroken[idx]=true;
            // LOW buzildi -> bullish MSS qidirishni boshlaymiz (barcha TF)
            g_mssUpWatch[idx]=true; g_loBreakTime[idx]=time[i];
            for(int t=0;t<MSS_TF_COUNT;t++) g_mssUpDone[idx][t]=false;
            if(allowAlerts)
               FireBreakoutAlert(idx,false,time[i],low[i]);
         }

         // chiziq buzilmaguncha o'ngga cho'ziladi, buzilgan barda to'xtaydi
         DrawLevel(idx,true,g_watchHigh[idx],time[i],hiWasBroken);
         DrawLevel(idx,false,g_watchLow[idx],time[i],loWasBroken);
      }
   }
}

//+------------------------------------------------------------------+
//| Oldingi kun HIGH/LOW (PDH/PDL)                                     |
//| useNy=false -> broker (terminal) kuni, useNy=true -> Nyu-York kuni |
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

   // yozuv o'ng chetda (oxirgi bar) turadi
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

// bitta kun turi (terminal yoki NY) uchun oldingi kun HIGH/LOW ni hisoblaydi,
// chizadi va narx buzganda alert beradi
void ProcessPrevDay(const int ratesTotal,const datetime &time[],
                    const double &high[],const double &low[],const double &close[],
                    const bool useNy,const bool allowAlerts)
{
   if(ratesTotal<2) return;

   datetime nowT=time[ratesTotal-1];
   datetime nowRef = useNy ? ServerToNewYork(nowT) : nowT;
   long todayIdx=(long)(nowRef/86400);
   long prevIdx =todayIdx-1;

   double hi=-DBL_MAX, lo=DBL_MAX; datetime firstT=0; bool found=false;
   for(int b=ratesTotal-1;b>=0;b--)
   {
      datetime tb = useNy ? ServerToNewYork(time[b]) : time[b];
      long idx=(long)(tb/86400);
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

   // kun turi bo'yicha holatni tanlaymiz
   string id     = useNy ? "NY"   : "TERM";
   string zone   = useNy ? "NY"   : "Terminal";
   color  clr    = useNy ? InpPrevDayNyColor : InpPrevDayTermColor;
   string hiLbl  = useNy ? "PDH (NY)" : "PDH";
   string loLbl  = useNy ? "PDL (NY)" : "PDL";

   long   prevDay   = useNy ? g_pdNyDay : g_pdTermDay;
   bool   hiBroken  = useNy ? g_pdNyHiBroken : g_pdTermHiBroken;
   bool   loBroken  = useNy ? g_pdNyLoBroken : g_pdTermLoBroken;

   // yangi kunga o'tsak - buzilish bayroqlarini yangilaymiz
   if(prevDay!=prevIdx)
   {
      hiBroken=false; loBroken=false;
      prevDay=prevIdx;
   }

   DrawPrevDayLine(id,true, hi,firstT,clr,hiLbl);
   DrawPrevDayLine(id,false,lo,firstT,clr,loLbl);

   // narx buzganda (bir marta) alert
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

   // holatni saqlaymiz
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
         for(int t=0;t<MSS_TF_COUNT;t++){ g_mssDnDone[i][t]=false; g_mssUpDone[i][t]=false; }
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

   // break dan keyin M1/M5/M15 da market structure shift qidirish
   ProcessAllMSS(allowAlerts);

   // oldingi kun HIGH/LOW (terminal kuni va Nyu-York kuni)
   if(InpEnablePrevDay)
   {
      ProcessPrevDay(rates_total,time,high,low,close,false,allowAlerts); // terminal
      ProcessPrevDay(rates_total,time,high,low,close,true, allowAlerts); // Nyu-York
   }

   return(rates_total);
}
