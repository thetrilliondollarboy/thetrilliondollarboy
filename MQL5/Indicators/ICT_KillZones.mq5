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
input color InpAsianColor       = clrDodgerBlue;   // Asian rangi
input color InpLondonColor      = clrOrange;       // London rangi
input color InpNewYorkColor     = clrLimeGreen;    // New York rangi
input color InpLondonCloseColor = clrViolet;       // London Close rangi
input bool  InpShowLabels       = true;             // Sessiya nomini chizish
input bool  InpShowHighLowArrow = true;             // Maksimum/minimum nuqtalarni strelka bilan belgilash
input color InpHighColor        = clrRed;           // Maksimum nuqta rangi
input color InpLowColor         = clrBlue;          // Minimum nuqta rangi

input group "== Tarix =="
input int InpHistoryDays = 5; // Nechta kunlik tarixni chizish

input group "== Ovozli/Popup Alert =="
input bool   InpEnableSoundAlert = true;       // Sessiya tugaganda ovozli signal chalinsin
input string InpSoundFile        = "alert.wav"; // Ovoz fayli (terminal Sounds papkasidagi)
input bool   InpEnablePopupAlert = true;       // Sessiya tugaganda ekranda xabar (Alert) chiqsin

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
string g_label[SESSION_COUNT] = {"Asian KZ","London KZ","New York KZ","London Close KZ"};

//--- running state per session ---------------------------------------------
bool     g_active[SESSION_COUNT];
datetime g_startTime[SESSION_COUNT];
datetime g_lastInTime[SESSION_COUNT];
double   g_high[SESSION_COUNT];
double   g_low[SESSION_COUNT];
datetime g_highTime[SESSION_COUNT];
datetime g_lowTime[SESSION_COUNT];

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

   for(int i=0;i<SESSION_COUNT;i++)
      g_active[i]=false;

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

bool IsInSession(const datetime nyTime,const int idx)
{
   int m=MinutesOfDay(nyTime);
   int startM=g_startHour[idx]*60+g_startMin[idx];
   int endM  =g_endHour[idx]*60+g_endMin[idx];
   int endEff=endM; if(endEff<=startM) endEff+=1440;
   int mEff=m;      if(mEff<startM)    mEff+=1440;
   return (mEff>=startM && mEff<endEff);
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
      ObjectSetInteger(0,name,OBJPROP_COLOR,g_color[idx]);
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

void SetArrow(const string name,const datetime t,const double price,const int code,const color clr,const bool anchorTop)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_ARROW,0,t,price);
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,code);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchorTop?ANCHOR_BOTTOM:ANCHOR_TOP);
   }
   else
   {
      ObjectSetInteger(0,name,OBJPROP_TIME,0,t);
      ObjectSetDouble (0,name,OBJPROP_PRICE,0,price);
   }
}

void DrawSessionMarkers(const int idx)
{
   if(!InpShowHighLowArrow) return;
   string hname="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+"_high";
   string lname="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+"_low";
   SetArrow(hname,g_highTime[idx],g_high[idx],SYMBOL_ARROWDOWN,InpHighColor,true);
   SetArrow(lname,g_lowTime[idx],g_low[idx],SYMBOL_ARROWUP,InpLowColor,false);
}

void DrawSessionLabel(const int idx)
{
   if(!InpShowLabels) return;
   string name="ICTKZ_"+g_key[idx]+"_"+MakeId(g_startTime[idx])+"_lbl";
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_TEXT,0,g_startTime[idx],g_high[idx]);
      ObjectSetString (0,name,OBJPROP_TEXT,g_label[idx]);
      ObjectSetInteger(0,name,OBJPROP_COLOR,g_color[idx]);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   else
   {
      ObjectSetInteger(0,name,OBJPROP_TIME,0,g_startTime[idx]);
      ObjectSetDouble (0,name,OBJPROP_PRICE,0,g_high[idx]);
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

void FireSessionAlert(const int idx)
{
   string text=StringFormat(
      "%s [%s]\n%s tugadi\nMax: %s (%s)\nMin: %s (%s)",
      _Symbol,
      EnumToString((ENUM_TIMEFRAMES)Period()),
      g_label[idx],
      DoubleToString(g_high[idx],_Digits),TimeToString(g_highTime[idx],TIME_DATE|TIME_MINUTES),
      DoubleToString(g_low[idx],_Digits),TimeToString(g_lowTime[idx],TIME_DATE|TIME_MINUTES)
   );

   if(InpEnableSoundAlert)
      PlaySound(InpSoundFile);
   if(InpEnablePopupAlert)
      Alert(text);
   if(InpEnableTelegram)
      SendTelegramMessage(text);
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
         DrawSessionMarkers(idx);
         DrawSessionLabel(idx);
      }
      else
      {
         if(g_active[idx])
         {
            g_active[idx]=false;
            if(allowAlerts)
               FireSessionAlert(idx);
         }
      }
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
         g_active[i]=false;

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

   return(rates_total);
}
