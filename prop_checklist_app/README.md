# ICT Prop Checklist — desktop dastur

Alohida oynada ochiladigan (kalkulyatordek) savdo checklisti. Har savdo
oldidan ICT setup shartlarini tekshiradi. **Qo'lda belgilash** va MetaTrader
indikatoridan **avtomatik ma'lumot olib o'zi tekshirib alert berish** rejimlari
bor. Avtomatik rejimni istalgan payt ON/OFF qilib qo'yish mumkin.

---

## 1. Talablar

- **Python 3.8+** (Windows'da odatda tkinter bilan birga keladi).
- MetaTrader 4 yoki 5 (avtomatik rejim uchun).

Tekshirish:
```
python --version
```

## Tayyor .exe ni yuklab olish (Python shart emas)

Windows uchun tayyor dastur GitHub'da avtomatik yasaladi:

1. Repozitoriyaning **Releases** bo'limiga o'ting → **"ICT Prop Checklist (Windows)"**.
2. **`ICT_Prop_Checklist.exe`** ni yuklab oling (yoki EA bilan birga `.zip`).
3. Ikki marta bosib ishga tushiring — o'rnatish kerak emas.
   (Windows SmartScreen ogohlantirsa: *More info → Run anyway*.)

> `.exe` yonida `config.json` avtomatik yaratiladi — barcha sozlamalaringiz
> shu yerda saqlanadi.

**O'zingiz yasamoqchi bo'lsangiz** (Python bor kompyuterda): `build_exe.bat`
faylni ikki marta bosing → `dist\ICT_Prop_Checklist.exe` hosil bo'ladi.

---

## 2. Manba koddan ishga tushirish (ixtiyoriy)

```
cd prop_checklist_app
python app.py
```

Alohida oyna ochiladi. Birinchi ishga tushishda yonida `config.json` yaratiladi
(barcha sozlama va o'zgartirishlar shu yerda saqlanadi).

---

## 3. Oynadagi imkoniyatlar

| Element | Vazifasi |
|---|---|
| **Checklist** | Har bir shart uchun katakcha. `AUTO` — indikatordan avtomatik, `QO'L` — o'zingiz bosasiz. |
| **+ Qo'shish** | Yangi checklist elementi qo'shish. |
| **Tahrirlash** | Elementlarni o'zgartirish / o'chirish / tartibini o'zgartirish (▲▼). |
| **Tozalash** | Barcha belgilarni nolga tushirish (yangi savdo uchun). |
| **Risk / Lot kalkulyator** | `Lot = Risk$ / (SL × 1 pip narxi)` — prop hisob uchun. |
| **AVTOMATIK** | Indikator faylini kuzatib borish rejimini yoqadi/o'chiradi. |
| **Ustida** | Oyna doim boshqa oynalar ustida turadi. |
| **Tovush** | Alert ovozini yoqadi/o'chiradi. |
| **⚙ Fayl** | MetaTrader eksport JSON faylini tanlash. |

Barcha shartlar (auto + qo'l) yashil bo'lganda dastur **"SETUP TAYYOR"**
degan alert va ovoz beradi.

---

## 4. Avtomatik rejimni ulash (MetaTrader)

Dastur MetaTrader'dan to'g'ridan-to'g'ri o'qiy olmaydi — u JSON faylni
kuzatib boradi. Faylni yozishning **2 yo'li** bor:

### ✅ Tavsiya: sizning ICT Kill Zones indikatoringiz bilan SINXRON

`metatrader/ICT_KillZones_Sync.mq5` — bu **sizning "ICT Kill Zones"
indikatoringizning aynan o'zi**, faqat ichiga JSON eksport qo'shilgan.
Shuning uchun checklist ekranda ko'rayotgan setup bilan **100% sinxron**
ishlaydi (killzone, Asia sweep, MSS, OTE, PDH/PDL — hammasi indikatorning
o'z hisobidan olinadi).

1. MT5 → **File → Open Data Folder** → `MQL5/Indicators/` papkasiga
   `ICT_KillZones_Sync.mq5` ni nusxalang.
2. MetaEditor'da oching → **Compile** (F7).
3. Grafikka tashlang (eski `ICT_KillZones` o'rniga). Sozlamalarda
   **"Checklist eksport (JSON)"** guruhi bor — `InpEnableExport = true`.
4. Indikator `MQL5/Files/killzone_data.json` faylini yozadi.
5. Dasturda **⚙ Fayl** → o'sha faylni tanlang → **AVTOMATIK** ni yoqing.

Checklist avtomatik belgilaydigan shartlar (indikatordan):

| Checklist elementi | Qoida | Indikator manbasi |
|---|---|---|
| Killzone ichidami | `killzone` | aktiv sessiya |
| Likvidlik olindimi | `liquidity` | Asia High/Low yoki PDH/PDL buzildi |
| MSS / Shift | `mss` | OTE TF da tasdiqlangan shift |
| OTE zona tayyormi | `ote` | sweep + shift → OTE chizildi |
| Yangilik yo'qmi | `no_news` | `InpNewsTimesCSV` sozlamasi |

> **Eslatma:** indikatorda standart holatda faqat **Asian** sessiya
> yoqilgan (`InpShowAsian=true`). Boshqa sessiya setuplari uchun tegishli
> `InpShow...` ni yoqing.

### Muqobil: mustaqil eksport EA (indikatorsiz)

Agar indikatorni qayta kompilyatsiya qilmoqchi bo'lmasangiz, killzone
ma'lumotini o'zi hisoblab beradigan EA ham bor.

### MT5 uchun
1. MetaTrader 5 → **File → Open Data Folder**.
2. `MQL5/Experts/` papkasiga `metatrader/AsiaKillzoneExporter.mq5` ni nusxalang.
3. MetaEditor'da oching va **Compile** (F7) bosing.
4. Grafikka (masalan GBPUSD M5) EA'ni tashlang. **Algo Trading** yoqilgan bo'lsin.
5. EA fayl yozadi: `MQL5/Files/killzone_data.json`.

### MT4 uchun
1. **File → Open Data Folder** → `MQL4/Experts/` ga `AsiaKillzoneExporter.mq4`.
2. Compile qiling, grafikka tashlang.
3. Fayl: `MQL4/Files/killzone_data.json`.

### Dasturga faylni ko'rsatish
1. Dasturda **⚙ Fayl** tugmasini bosing.
2. Yuqoridagi `killzone_data.json` faylni tanlang.
3. **AVTOMATIK** katakchasini yoqing. Yashil nuqta = ulangan.

> **MUHIM — vaqt zonasi:** EA'dagi soatlar **broker/server vaqti** bo'yicha.
> Rasmingizdagi killzone vaqtlariga moslash uchun EA sozlamalaridagi
> `AsiaStartHour`, `LondonStart/End`, `NYStart/End` va h.k. ni brokeringiz
> server vaqtiga qarab bir marta to'g'rilang.

---

## 5. Avtomatik tekshiriladigan shartlar (qoidalar)

Element qo'sh/tahrirlaganda "Avtomatik manba" ni tanlaysiz:

| Qoida | Ma'nosi (fayldan) |
|---|---|
| `killzone` | Hozir killzone ichidami? (`killzone` != None) |
| `liquidity` | Likvidlik olindimi? (asia/pdh/pdl sweep) |
| `mss` | Struktura buzildimi? (`mss` = bullish/bearish) |
| `no_news` | Yangilik oynasidan tashqarimi? |
| `manual` | Faqat qo'lda (OTE/Breaker, RR, risk kabi qaror talab qiladiganlar) |

OTE/Breaker entry, RR ≥ 1:2 va risk kabi qaror talab qiladigan shartlar
ataylab **qo'lda** qoldirilgan — ularni siz tasdiqlaysiz.

---

## 6. Tez sinov (MetaTrader'siz)

Avtomatik rejimni sinab ko'rish uchun `sample_killzone_data.json` bor:
1. **⚙ Fayl** → `sample_killzone_data.json` ni tanlang.
2. **AVTOMATIK** ni yoqing → auto shartlar yashil bo'ladi.
3. `manual` shartlarni qo'lda belgilang → "SETUP TAYYOR" alerti chiqadi.

---

## 7. Fayl tuzilishi (data contract)

EA yozadigan / dastur o'qiydigan JSON:

```json
{
  "timestamp": "2026-07-16 09:15:00",
  "symbol": "GBPUSD",
  "bid": 1.26790,
  "asia_high": 1.27100,
  "asia_low": 1.26800,
  "pdh": 1.27500,
  "pdl": 1.26500,
  "killzone": "London",
  "asia_low_swept": true,
  "asia_high_swept": false,
  "pdh_swept": false,
  "pdl_swept": false,
  "mss": "bullish",
  "news_window": false
}
```

Agar o'zingizning indikatoringiz bor bo'lsa, uni shu formatda fayl yozadigan
qilib sozlasangiz — dastur to'g'ridan-to'g'ri undan o'qiydi (EA shart emas).

---

## Muhim eslatma

Bu dastur — **intizom vositasi**, savdo signali yoki foyda kafolati emas.
Avtomatik MSS aniqlash oddiy heuristika (break of structure) — uni
grafikdan ko'z bilan ham tasdiqlang. Yakuniy qaror har doim sizniki.
