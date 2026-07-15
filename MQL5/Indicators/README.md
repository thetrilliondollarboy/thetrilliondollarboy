# ICT Killzones Toolkit (MT5 / MQL5)

TradingView'dagi **LuxAlgo — ICT Killzones Toolkit** indikatorining
MetaTrader 5 uchun **to'liq, mustaqil** qayta-yozilgan versiyasi.
Barcha sozlamalar va izohlar **o'zbek tilida**.

> Bu LuxAlgo'ning yopiq (proprietary) Pine Script kodining nusxasi **emas** —
> xuddi shu funksionallik noldan MQL5 da yozilgan.

## To'liq imkoniyatlar (asl toolkitdagidek)

### 1. KILLZONES
- 4 ta sessiya: **Asian**, **London**, **New York**, **New York PM**
- Har biri: yoqish/o'chirish, nom, boshlanish/tugash vaqti, rang
- **Killzone chiziqlari**: Tepa/Past (Top/Bottom) + **O'rta chiziq (Mean)**
- **Extend Top/Bottom** — chiziqlarni o'ngga cho'zish
- **Killzone yorliqlari** (Labels)
- **Ochilish narxi** (Open Price of): Kunlik / Haftalik / Oylik + **Ajratgich (Separator)**
- **Timeframe filtri** — killzone'lar faqat belgilangan TF gacha ko'rinadi

### 2. ORDER BLOCKS & BREAKER BLOCKS
- Killzone ichida **Order Block** va **Breaker Block** aniqlash
- **Swing aniqlash uzunligi**
- **Mitigatsiya narxi**: Close yoki Wick
- **Shamning tanasidan** foydalanish opsiyasi
- Mitigatsiya qilinganlarni o'chirish / o'ngga cho'zish
- Bullish/Bearish OB va BB uchun alohida ranglar

### 3. MARKET STRUCTURE SHIFTS (MSS)
- Killzone ichida **struktura buzilishini** aniqlash
- **Aniqlash uzunligi** (Detection Length)
- Bullish/Bearish ranglar va matn

### 4. FAIR VALUE GAPS (FVG)
- Killzone ichida **imbalans (FVG)** aniqlash
- **Kenglik filtri** (o'zini-normallashtiruvchi)
- Mitigatsiya qilinganlarni o'chirish / o'ngga cho'zish
- Bullish/Bearish imbalans ranglari

### 5. CRT (Candle Range Theory)
- Yuqori timeframe (HTF) **range candle**'ini aniqlaydi
- **Manipulation candle** diapazon low/high'ini **sweep** qilib qaytadan
  ichkariga yopilishini topadi (**TBS — Turtle Body Soup**)
- **Diapazon qutisi** + **0% / 50% / 100%** darajalari
- Bullish/Bearish CRT ranglari, TBS sweep belgisi, "CRT" yorlig'i
- Faqat killzone ichidagilarini ko'rsatish opsiyasi
- Yangi CRT modelida alert

### Qo'shimcha
- **Dashboard** — har sessiyaning FAOL/yopiq holati
- **Ko'rsatish rejimi** (har bo'lim uchun): Birinchisi / Barchasi / O'chirilgan
- **Timezone offset** — broker vaqtini moslash

## O'rnatish

1. `ICT_Killzones.mq5` faylini MT5 dagi `MQL5/Indicators/` papkasiga ko'chiring.
2. MetaEditor'da oching va **F7** (Compile) bosing.
3. Navigator → Indicators → `ICT_Killzones` ni grafikka tashlang.

## Muhim: vaqt mintaqasi

Killzone vaqtlari **broker server vaqtida** kiritiladi. Rasmlardagi standart
vaqtlar (Asian 19:00–23:05, London 01:00–04:05, New York 06:00–09:05,
New York PM 13:30–16:00) UTC ga yaqin broker uchun. Agar brokeringiz vaqti
farq qilsa, **Broker vaqti ofseti** inputidan foydalanib moslang.

## Eslatma

Order Blocks, Breaker Blocks, MSS va FVG aniqlash algoritmlari ICT
konsepsiyasining standart, ochiq implementatsiyasidir. Ular asl toolkit
bilan bir xil g'oyaga asoslanadi, ammo piksel-darajada aynan bir xil
natija berishi shart emas. Sozlamalarni o'z savdo uslubingizga moslang.
