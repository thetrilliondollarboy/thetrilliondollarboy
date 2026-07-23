# ICT MetaTrader 5 indikatorlari

Ushbu repozitoriyada ICT / Smart Money konsepsiyalari asosidagi MT5 indikatorlari:

| Fayl | Nima qiladi |
|------|-------------|
| `ICT_SmartMoney.mq5` | Market Structure (BOS/CHoCH), Order Block + FVG, Liquidity (BSL/SSL) sweep, Killzone + Silver Bullet |
| `ICT_AMD_PowerOfThree.mq5` | AMD zonalar: Accumulation → Manipulation → Distribution (Power of Three) |

Barchasi **universal** — har qanday instrument va timeframe uchun. Indikatorlar
avtomatik savdo qilmaydi, faqat grafikda zonalar/signallarni chizadi.

---

## 1) ICT_SmartMoney.mq5 — Smart Money Concepts

ICT / Smart Money konsepsiyalari asosida ishlovchi
MetaTrader 5 grafik indikatori. **Universal**: har qanday instrument va
timeframe uchun ishlaydi. Indikator avtomatik savdo qilmaydi — u faqat
grafikda zonalar, chiziqlar va signallarni chizadi (qo'lda savdo uchun).

## Modullar

| # | Modul | Nima chizadi |
|---|-------|--------------|
| 1 | **Market Structure** | Swing High/Low (HH, HL, LH, LL), **BOS** (Break of Structure) va **CHoCH** (Change of Character) chiziqlari |
| 2 | **Order Block + FVG** | Bullish/Bearish **Order Block** zonalari va **Fair Value Gap** (imbalance) to'rtburchaklari |
| 3 | **Liquidity (BSL/SSL)** | Teng high/low darajalari (Buy-side / Sell-side liquidity) va **liquidity sweep** belgilari |
| 4 | **Killzone + Silver Bullet** | Asia / London / New York savdo seanslari qutilari va NY **Silver Bullet** (10:00–11:00 EST) oynasi |

## O'rnatish

1. MetaTrader 5 da: `File → Open Data Folder`.
2. `MQL5/Indicators/` papkasiga `ICT_SmartMoney.mq5` faylini nusxalang.
3. MetaEditor da faylni oching va **F7** (Compile) bosing — `ICT_SmartMoney.ex5` hosil bo'ladi.
4. MT5 da `Navigator → Indicators` dan grafikka tashlang.

## Asosiy sozlamalar (Inputs)

### Umumiy
- `InpHistoryBars` — tahlil qilinadigan bar soni (default 600).
- `InpSwingStrength` — swing kuchi: markaziy barning chap/o'ng tomonidagi barlar soni (default 3). Kichikroq = ko'proq swing, kattaroq = faqat yirik swinglar.
- `InpAlertsOn` — BOS/CHoCH yuz berganda alert (xabarnoma).

### Market Structure
- `InpShowStructure`, `InpShowSwings` — modul/yorliqlarni yoqish.
- `InpBosColor`, `InpChochColor` — BOS va CHoCH ranglari.

### Order Block + FVG
- `InpShowOB`, `InpShowFVG` — modullarni yoqish.
- `InpBullOBColor`, `InpBearOBColor`, `InpBullFVGColor`, `InpBearFVGColor` — ranglar.
- `InpMaxOB` — har turdan grafikda saqlanadigan maksimal zona soni (eskilari avto o'chadi).

### Liquidity
- `InpShowLiquidity`, `InpShowSweep` — modul va sweep belgilarini yoqish.
- `InpEqTolerancePts` — teng daraja toleransi (punktda). **0** = avtomatik (oxirgi 50 barning o'rtacha diapazonidan 15%).

### Killzone
- `InpShowKillzones`, `InpShowSilver` — seans qutilari va Silver Bullet oynasi.
- `InpGmtOffset` — **brokeringizning server vaqti GMT ofseti** (soat). Seanslar to'g'ri joylashishi uchun buni to'g'ri kiriting (masalan, ko'p brokerlarda yozda +3, qishda +2).

## Killzone vaqtlari (GMT)

| Seans | GMT oralig'i |
|-------|--------------|
| Asia | 00:00 – 06:00 |
| London | 07:00 – 10:00 |
| New York | 12:00 – 15:00 |
| Silver Bullet | 14:00 – 15:00 (≈ 10:00–11:00 EST) |

Indikator bu GMT soatlarini `InpGmtOffset` orqali server vaqtiga o'tkazadi.

## Eslatma

Bu vosita o'qув/tahlil maqsadida. Hech qanday indikator daromad kafolatlamaydi —
har doim risk-menejment qoidalariga amal qiling va demo hisobda sinab ko'ring.

---

## 2) ICT_AMD_PowerOfThree.mq5 — AMD zonalar (Power of Three)

**Vaqtga (kun boshi/oxiri, sessiya) bog'liq emas.** AMD sikllari **bar soniga**
asoslangan holda **ketma-ket, yonma-yon** chiziladi. Har bir sikl:

- **A — Accumulation**: `InpAccBars` ta barlik yig'ilish diapazoni. Grafikda kulrang quti (high/low).
- **M — Manipulation**: accumulationdan keyingi `InpScanBars` oynasida diapazon high yoki low'ining birinchi sindirilishi (liquidity sweep). Sweep ekstremumida **M** belgisi.
- **D — Distribution**: sweepga **teskari** haqiqiy narx harakati (`InpDistBars` uzunlikda chiziladi). **Target yo'q.**

Har bir sikl manipulyatsiyadan keyin darrov yangisi bilan davom etadi — shuning
uchun zonalar grafikni uzluksiz, ketma-ket qoplaydi.

### Asosiy sozlamalar

- `InpAccBars` — accumulation diapazoni uzunligi (bar). Kichikroq = tez-tez sikllar.
- `InpScanBars` — manipulyatsiyani izlash oynasi (bar).
- `InpDistBars` — distribution chizig'i uzunligi (bar).
- `InpAlertOnManip` — oxirgi (eng so'nggi) sikl manipulyatsiyasida alert.

### Ishlash mantig'i

Manipulyatsiya tomoni = accumulation diapazonining birinchi sindirilgan tomoni
(yuqoriga sweep → bearish distribution; pastga sweep → bullish distribution).
Bu ICT'ning "liquidity ustidan olib, teskari yo'nalishga jo'natish" g'oyasiga mos.

---

## Umumiy eslatma

Bu vositalar o'quv/tahlil maqsadida. Hech qanday indikator daromad kafolatlamaydi —
har doim risk-menejment qoidalariga amal qiling va demo hisobda sinab ko'ring.
Algoritmlar ICT konsepsiyalarining soddalashtirilgan talqini — turli treyderlar
ularni biroz farqli aniqlashi mumkin.
