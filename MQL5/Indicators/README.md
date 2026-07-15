# ICT Killzones + Sessions (MT5 / MQL5)

TradingView'dagi LuxAlgo "ICT Killzones + Sessions" toolkit konsepsiyasining
MetaTrader 5 uchun **mustaqil, ochiq** qayta-yozilgan versiyasi. Bu LuxAlgo'ning
yopiq (proprietary) Pine Script kodining nusxasi emas — bir xil ICT killzone
funksionalligi noldan MQL5 da yozilgan.

## Imkoniyatlar

- 4 ta ICT killzone: **New York**, **London Open**, **London Close**, **Asia**
- Har sessiya uchun **range box** (high/low) — fill + border
- Sessiya **High / Low** chiziqlari (ixtiyoriy o'ngga cho'ziladi)
- **Mean threshold (50% equilibrium)** chizig'i
- Sessiya nom **label**lari
- Killzone ichidagi **pivot high / low** aniqlash
- **Dashboard** jadvali (har sessiyaning ACTIVE/closed holati)
- **Timezone offset** — broker vaqtini killzone vaqtiga moslash

## O'rnatish

1. `ICT_Killzones.mq5` faylini MetaTrader 5 dagi
   `MQL5/Indicators/` papkasiga ko'chiring.
2. MetaEditor'da oching va **F7** (Compile) bosing.
3. MT5 Navigator → Indicators → `ICT_Killzones` ni grafikka tashlang.

## Muhim: Timezone (vaqt mintaqasi)

Killzone vaqtlari (Start/End) **broker server vaqtida** kiritiladi.
Agar sizning brokeringiz vaqti kerakli vaqtdan farq qilsa,
`Broker offset (hours)` inputidan foydalanib moslang.

Standart ICT killzone vaqtlari (New York / EST) misol tariqasida berilgan —
o'z brokeringiz vaqt mintaqasiga qarab Start/End qiymatlarini sozlang.

## Asosiy sozlamalar (Inputs)

| Guruh | Nima |
|-------|------|
| General | Offset, tarix kunlari, box/label/high-low/mean/pivot ko'rsatish |
| New York / London Open / London Close / Asia | Har biri: yoqish, nom, Start, End, rang |
| Dashboard | Jadval burchagi, o'rni, ranglari |

## Eslatma

Bu indikator ta'lim va tahlil maqsadida yozilgan. Killzone vaqtlarini
o'z savdo rejangizga va broker vaqtingizga moslab sozlang.
