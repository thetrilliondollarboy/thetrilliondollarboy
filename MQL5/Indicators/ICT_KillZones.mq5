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
   {
      g_active[i]=false;
      g_watching[i]=false;
      g_highBroken[i]=false;
      g_lowBroken[i]=false;
   }

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
            g_watching[idx]=false; // yangi sessiya boshlandi - eski buzilish kuzatuvi to'xtaydi
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
            if(allowAlerts)
               FireBreakoutAlert(idx,true,time[i],high[i]);
         }
         if(!g_lowBroken[idx] && low[i]<g_watchLow[idx])
         {
            g_lowBroken[idx]=true;
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
      }

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
