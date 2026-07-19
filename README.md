# Liquidity Sweep Alerts (MT5)

MetaTrader 5 uchun **likvidlik darajalari indikatori**. Grafikda barcha asosiy
likvidlik darajalarini avtomatik chizadi va daraja **sweep** (olib bo'lingan)
qilinganda **atigi 1 marta ovozli alert** beradi.

> **Muhim:** timeframe (M15 → H1 → H4 va h.k.) almashtirilganda alert
> **qayta-qayta ishlamaydi**. Sweep holati terminalning **GlobalVariable**larida
> saqlanadi, shuning uchun grafik/TF qayta yuklansa ham bir daraja ikkinchi marta
> signal bermaydi.

## Belgilanadigan likvidliklar (rasmga mos)

| Daraja | Tavsif |
|---|---|
| **Previous Day** High & Low | Oldingi kun eng yuqori/pasti |
| **Previous Week** High & Low | Oldingi hafta eng yuqori/pasti |
| **Previous Month** High & Low | Oldingi oy eng yuqori/pasti |
| **Previous Session** High & Low | Osiyo / London / New-York sessiyalari |
| **4H Candle** High & Low | Oldingi 4 soatlik svecha eng yuqori/pasti |
| **Swing Structure** High & Low | Fraktal swing nuqtalari |
| **Equal** High & Low (EQH/EQL) | Bir xil (tekis) yuqori/pastliklar |

## O'rnatish

1. `LiquiditySweepAlerts.mq5` faylini quyidagi papkaga qo'ying:
   `MQL5/Indicators/` (MetaTrader 5 → **File → Open Data Folder**).
2. **MetaEditor**da faylni oching va **Compile** (F7) bosing.
3. MT5 da **Navigator → Indicators** ichidan grafikka tashlang.
4. **Common** tabida **Allow DLL/Alerts** shart emas, lekin ovoz uchun
   MT5 → **Tools → Options → Events** yoqilgan bo'lsin. Ovoz fayli
   `MQL5/Files/` yoki terminal `Sounds` papkasida bo'lishi kerak
   (`alert2.wav` standart mavjud).

## Muhim sozlamalar

- **DARAJALAR (yoq/och)** — har bir likvidlik turini alohida yoqib/o'chirish va
  rangini tanlash.
- **SESSIYALAR** — sessiya boshlanish/tugash **soatlari (server vaqtida)**.
  Brokeringiz vaqti GMT+2/+3 bo'lishi mumkin, shunga qarab moslang.
- **SWING / EQUAL** — `SwingStrength` (swing kuchi), `SwingCount` (nechta swing),
  `EqualTolerancePts` (Equal H/L uchun punktdagi tolerantlik).
- **ALERT**:
  - `PlaySoundAlert` — ovozli signal, `SoundFile` — ovoz fayli nomi.
  - `PopupAlert` — ekranga chiquvchi Alert oynasi.
  - `PushAlert` — telefon ilovasiga bildirishnoma (MetaQuotes ID sozlangan bo'lsin).
  - `SweepOnWick` — `true`: fitil tegsa alert; `false`: svecha yopilishi kerak.
  - `AlertOnlyNew` — `true`: indikator ulangan paytdagi eski (allaqachon olingan)
    sweeplar uchun ovoz **bermaydi**, faqat yangilariga.
- **StatePersistDays** — sweep holati necha kun saqlanadi (eski yozuvlar avtomatik
  tozalanadi, terminal ortiqcha to'lib ketmasligi uchun).

## Sweep mantiqi

- **Yuqori** likvidlik (masalan Prev Day High): narx daraja **ustidan** o'tsa —
  buy-side sweep.
- **Pastki** likvidlik (masalan Prev Day Low): narx daraja **ostidan** o'tsa —
  sell-side sweep.

Har bir aniq daraja (turi + narxi) uchun signal **umrida bir marta** beriladi.
