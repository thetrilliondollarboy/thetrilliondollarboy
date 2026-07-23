#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ICT Prop Checklist — standalone desktop oyna (kalkulyatordek).

Imkoniyatlari:
  * Alohida oynada ochiladigan checklist (har savdo oldidan tekshirish).
  * QO'LDA belgilash (manual) — checkboxni o'zingiz bosasiz.
  * AVTOMATIK rejim — MetaTrader indikatori/EA yozgan JSON fayldan
    ma'lumot olib (Asia killzone, sweep, MSS, news) checklistni o'zi
    belgilaydi va hammasi tayyor bo'lganda ALERT beradi.
  * Auto rejimini ON/OFF qilib qo'yish tugmasi.
  * Checklist elementlarini qo'shish / o'zgartirish / o'chirish.
  * Risk / Lot kalkulyatori (prop hisob uchun).
  * "Always on top" — oyna doim ustida turadi.

Ishga tushirish:
    python app.py
Faqat standart kutubxonalar (tkinter) kerak — o'rnatish shart emas.
"""

import json
import os
import sys
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

# .exe (PyInstaller) rejimida config faylni .exe yonida saqlash uchun
if getattr(sys, "frozen", False):
    APP_DIR = os.path.dirname(sys.executable)
else:
    APP_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(APP_DIR, "config.json")

# ---------------------------------------------------------------------------
# Avtomatik tekshirish qoidalari (MetaTrader eksport fayli ustida ishlaydi)
# Har bir qoida (symbol, data) -> (bool tayyor, izoh) qaytaradi.
# ---------------------------------------------------------------------------
def _truthy(v):
    return str(v).strip().lower() in ("1", "true", "yes", "on", "bullish", "bearish")

def rule_killzone(data):
    kz = str(data.get("killzone", "")).strip()
    ok = kz not in ("", "None", "Off", "0", "no")
    return ok, (kz if kz else "yo'q")

def rule_liquidity(data):
    keys = ("asia_low_swept", "asia_high_swept", "pdh_swept", "pdl_swept")
    hit = [k.replace("_swept", "") for k in keys if _truthy(data.get(k))]
    return (len(hit) > 0), (", ".join(hit) if hit else "olinmagan")

def rule_mss(data):
    m = str(data.get("mss", "")).strip().lower()
    ok = m in ("bullish", "bearish")
    return ok, (m if m else "yo'q")

def rule_no_news(data):
    news = _truthy(data.get("news_window"))
    return (not news), ("YANGILIK VAQTI!" if news else "toza")

def rule_ote(data):
    ok = _truthy(data.get("ote_ready"))
    return ok, ("zona tayyor" if ok else "yo'q")

def rule_always_manual(data):
    # Auto qoidasi yo'q — faqat qo'lda belgilanadi.
    return None, "qo'lda"

RULES = {
    "killzone": ("Killzone ichidamanmi?", rule_killzone),
    "liquidity": ("Likvidlik olindimi? (Asia/PDH/PDL)", rule_liquidity),
    "mss": ("MSS / Shift bo'ldimi?", rule_mss),
    "no_news": ("Yangilik yo'qmi (±30 daqiqa)?", rule_no_news),
    "ote": ("OTE zona tayyormi? (indikatordan)", rule_ote),
    "manual": ("(faqat qo'lda)", rule_always_manual),
}

# ---------------------------------------------------------------------------
# Standart konfiguratsiya (birinchi ishga tushishda yaratiladi)
# ---------------------------------------------------------------------------
DEFAULT_CONFIG = {
    "data_file": "",            # MetaTrader eksport JSON fayl yo'li
    "poll_seconds": 3,          # necha soniyada bir tekshirsin
    "auto_enabled": False,      # avtomatik rejim yoqilganmi
    "always_on_top": True,
    "sound_alert": True,
    "risk_amount": 400.0,       # har savdo riski ($)
    "balance": 47800.0,
    "items": [
        {"text": "Killzone ichidamanmi?",              "rule": "killzone",  "checked": False},
        {"text": "Likvidlik olindimi? (Asia/PDH/PDL)", "rule": "liquidity", "checked": False},
        {"text": "MSS / Shift bo'ldimi?",              "rule": "mss",       "checked": False},
        {"text": "Entry OTE (0.618-0.786) yoki Breaker retest?", "rule": "manual", "checked": False},
        {"text": "SL sweep narigi tomonida, RR >= 1:2?", "rule": "manual", "checked": False},
        {"text": "Risk aniq belgilangan (lot hisoblangan)?", "rule": "manual", "checked": False},
        {"text": "Yangilik yo'qmi (+/-30 daqiqa)?",     "rule": "no_news",   "checked": False},
    ],
}


def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                cfg = json.load(f)
            # yetishmayotgan kalitlarni to'ldirish
            for k, v in DEFAULT_CONFIG.items():
                cfg.setdefault(k, v)
            return cfg
        except Exception:
            pass
    return json.loads(json.dumps(DEFAULT_CONFIG))


def save_config(cfg):
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print("config saqlanmadi:", e)


# ---------------------------------------------------------------------------
# Tovushli signal (platformaga qarab)
# ---------------------------------------------------------------------------
def beep():
    try:
        if sys.platform.startswith("win"):
            import winsound
            winsound.MessageBeep(winsound.MB_ICONEXCLAMATION)
        else:
            sys.stdout.write("\a")
            sys.stdout.flush()
    except Exception:
        pass


# ===========================================================================
# ASOSIY ILOVA
# ===========================================================================
class ChecklistApp:
    COL_GREEN = "#1e8e3e"
    COL_RED = "#d93025"
    COL_GRAY = "#9aa0a6"
    COL_BG = "#1f2430"
    COL_CARD = "#2b303b"
    COL_TXT = "#e8eaed"

    def __init__(self, root):
        self.root = root
        self.cfg = load_config()
        self.item_widgets = []           # (BooleanVar, status_label, item_dict)
        self.last_data = {}
        self.last_data_mtime = None
        self.monitor_stop = threading.Event()
        self.monitor_thread = None
        self.alerted = False

        root.title("ICT Prop Checklist")
        root.configure(bg=self.COL_BG)
        root.geometry("430x720")
        root.minsize(400, 560)
        self._apply_on_top()

        self._build_style()
        self._build_header()
        self._build_checklist()
        self._build_calc()
        self._build_footer()

        root.protocol("WM_DELETE_WINDOW", self.on_close)
        if self.cfg.get("auto_enabled"):
            self.start_monitor()
        self._refresh_status_display()

    # ---------- stil ----------
    def _build_style(self):
        st = ttk.Style()
        try:
            st.theme_use("clam")
        except Exception:
            pass
        st.configure("TFrame", background=self.COL_BG)
        st.configure("Card.TFrame", background=self.COL_CARD)
        st.configure("TLabel", background=self.COL_BG, foreground=self.COL_TXT)
        st.configure("Card.TLabel", background=self.COL_CARD, foreground=self.COL_TXT)
        st.configure("TButton", padding=4)
        st.configure("TCheckbutton", background=self.COL_CARD, foreground=self.COL_TXT)
        st.map("TCheckbutton", background=[("active", self.COL_CARD)])

    def _apply_on_top(self):
        self.root.attributes("-topmost", bool(self.cfg.get("always_on_top")))

    # ---------- header ----------
    def _build_header(self):
        top = tk.Frame(self.root, bg=self.COL_BG)
        top.pack(fill="x", padx=10, pady=(10, 4))
        tk.Label(top, text="ICT SAVDO CHECKLIST", bg=self.COL_BG, fg=self.COL_TXT,
                 font=("Segoe UI", 13, "bold")).pack(side="left")
        self.dot = tk.Label(top, text="●", bg=self.COL_BG, fg=self.COL_GRAY,
                            font=("Segoe UI", 14))
        self.dot.pack(side="right")

        self.status_line = tk.Label(self.root, text="Auto: o'chiq", bg=self.COL_BG,
                                    fg=self.COL_GRAY, font=("Segoe UI", 9))
        self.status_line.pack(fill="x", padx=12)

    # ---------- checklist ----------
    def _build_checklist(self):
        wrap = tk.Frame(self.root, bg=self.COL_BG)
        wrap.pack(fill="both", expand=True, padx=10, pady=6)

        self.list_frame = tk.Frame(wrap, bg=self.COL_BG)
        self.list_frame.pack(fill="both", expand=True)
        self._render_items()

        btns = tk.Frame(self.root, bg=self.COL_BG)
        btns.pack(fill="x", padx=10)
        ttk.Button(btns, text="+ Qo'shish", command=self.add_item).pack(side="left", expand=True, fill="x", padx=2)
        ttk.Button(btns, text="Tahrirlash", command=self.edit_items).pack(side="left", expand=True, fill="x", padx=2)
        ttk.Button(btns, text="Tozalash", command=self.reset_checks).pack(side="left", expand=True, fill="x", padx=2)

    def _render_items(self):
        for w in self.list_frame.winfo_children():
            w.destroy()
        self.item_widgets = []
        for idx, item in enumerate(self.cfg["items"]):
            card = tk.Frame(self.list_frame, bg=self.COL_CARD)
            card.pack(fill="x", pady=3)
            var = tk.BooleanVar(value=item.get("checked", False))
            cb = tk.Checkbutton(
                card, variable=var, bg=self.COL_CARD, fg=self.COL_TXT,
                activebackground=self.COL_CARD, activeforeground=self.COL_TXT,
                selectcolor=self.COL_CARD, highlightthickness=0, bd=0,
                anchor="w", justify="left", wraplength=300,
                text=item.get("text", ""), font=("Segoe UI", 10),
                command=lambda i=idx: self._on_manual_toggle(i),
            )
            cb.pack(side="left", fill="x", expand=True, padx=(6, 2), pady=6)
            rule = item.get("rule", "manual")
            tag = "AUTO" if rule != "manual" else "QO'L"
            status = tk.Label(card, text=tag, bg=self.COL_CARD, fg=self.COL_GRAY,
                              font=("Segoe UI", 8, "bold"), width=8)
            status.pack(side="right", padx=6)
            self.item_widgets.append((var, status, item))

    def _on_manual_toggle(self, idx):
        var, _, item = self.item_widgets[idx]
        item["checked"] = var.get()
        save_config(self.cfg)
        self._update_ready_dot()

    def reset_checks(self):
        for var, _, item in self.item_widgets:
            # avto elementlar keyingi pollda qayta belgilanadi
            var.set(False)
            item["checked"] = False
        self.alerted = False
        save_config(self.cfg)
        self._update_ready_dot()

    # ---------- risk kalkulyator ----------
    def _build_calc(self):
        card = tk.LabelFrame(self.root, text=" Risk / Lot kalkulyator ",
                             bg=self.COL_CARD, fg=self.COL_TXT, bd=1,
                             font=("Segoe UI", 9, "bold"))
        card.pack(fill="x", padx=10, pady=(4, 6))

        row1 = tk.Frame(card, bg=self.COL_CARD); row1.pack(fill="x", padx=6, pady=3)
        tk.Label(row1, text="Risk ($):", bg=self.COL_CARD, fg=self.COL_TXT,
                 width=10, anchor="w").pack(side="left")
        self.e_risk = tk.Entry(row1, width=10)
        self.e_risk.insert(0, str(self.cfg.get("risk_amount", 400)))
        self.e_risk.pack(side="left")
        tk.Label(row1, text="SL (pip/punkt):", bg=self.COL_CARD, fg=self.COL_TXT,
                 anchor="w").pack(side="left", padx=(10, 4))
        self.e_sl = tk.Entry(row1, width=8)
        self.e_sl.insert(0, "20")
        self.e_sl.pack(side="left")

        row2 = tk.Frame(card, bg=self.COL_CARD); row2.pack(fill="x", padx=6, pady=3)
        tk.Label(row2, text="1 lot pip $:", bg=self.COL_CARD, fg=self.COL_TXT,
                 width=10, anchor="w").pack(side="left")
        self.e_pip = tk.Entry(row2, width=10)
        self.e_pip.insert(0, "10")
        self.e_pip.pack(side="left")
        ttk.Button(row2, text="Hisobla", command=self.calc_lot).pack(side="left", padx=10)

        self.lbl_lot = tk.Label(card, text="Lot = —", bg=self.COL_CARD, fg=self.COL_GREEN,
                                font=("Segoe UI", 12, "bold"))
        self.lbl_lot.pack(fill="x", padx=6, pady=(2, 6))

    def calc_lot(self):
        try:
            risk = float(self.e_risk.get())
            sl = float(self.e_sl.get())
            pip = float(self.e_pip.get())
            if sl <= 0 or pip <= 0:
                raise ValueError
            lot = risk / (sl * pip)
            self.lbl_lot.config(text=f"Lot = {lot:.2f}   (risk ${risk:.0f}, SL {sl:.0f})")
            self.cfg["risk_amount"] = risk
            save_config(self.cfg)
        except Exception:
            self.lbl_lot.config(text="Xato: raqamlarni tekshiring", )

    # ---------- footer / sozlamalar ----------
    def _build_footer(self):
        bar = tk.Frame(self.root, bg=self.COL_BG)
        bar.pack(fill="x", padx=10, pady=(0, 10))
        self.auto_var = tk.BooleanVar(value=self.cfg.get("auto_enabled", False))
        self.auto_btn = tk.Checkbutton(
            bar, text="AVTOMATIK", variable=self.auto_var, command=self.toggle_auto,
            bg=self.COL_BG, fg=self.COL_TXT, selectcolor=self.COL_CARD,
            activebackground=self.COL_BG, activeforeground=self.COL_TXT,
            font=("Segoe UI", 9, "bold"))
        self.auto_btn.pack(side="left")

        self.top_var = tk.BooleanVar(value=self.cfg.get("always_on_top", True))
        tk.Checkbutton(bar, text="Ustida", variable=self.top_var, command=self.toggle_top,
                       bg=self.COL_BG, fg=self.COL_TXT, selectcolor=self.COL_CARD,
                       activebackground=self.COL_BG, activeforeground=self.COL_TXT,
                       font=("Segoe UI", 9)).pack(side="left", padx=8)

        self.snd_var = tk.BooleanVar(value=self.cfg.get("sound_alert", True))
        tk.Checkbutton(bar, text="Tovush", variable=self.snd_var, command=self.toggle_sound,
                       bg=self.COL_BG, fg=self.COL_TXT, selectcolor=self.COL_CARD,
                       activebackground=self.COL_BG, activeforeground=self.COL_TXT,
                       font=("Segoe UI", 9)).pack(side="left")

        ttk.Button(bar, text="⚙ Fayl", command=self.choose_data_file).pack(side="right")

    # ---------- sozlama tugmalari ----------
    def toggle_auto(self):
        self.cfg["auto_enabled"] = self.auto_var.get()
        save_config(self.cfg)
        if self.cfg["auto_enabled"]:
            if not self.cfg.get("data_file"):
                messagebox.showwarning("Fayl yo'q",
                    "Avval MetaTrader eksport JSON faylini tanlang (⚙ Fayl).")
                self.auto_var.set(False)
                self.cfg["auto_enabled"] = False
                save_config(self.cfg)
                return
            self.start_monitor()
        else:
            self.stop_monitor()
        self._refresh_status_display()

    def toggle_top(self):
        self.cfg["always_on_top"] = self.top_var.get()
        self._apply_on_top()
        save_config(self.cfg)

    def toggle_sound(self):
        self.cfg["sound_alert"] = self.snd_var.get()
        save_config(self.cfg)

    def choose_data_file(self):
        path = filedialog.askopenfilename(
            title="MetaTrader eksport JSON faylini tanlang",
            filetypes=[("JSON", "*.json"), ("Barchasi", "*.*")])
        if path:
            self.cfg["data_file"] = path
            save_config(self.cfg)
            messagebox.showinfo("Saqlandi", f"Fayl:\n{path}")
            self._refresh_status_display()

    # ---------- checklist tahrirlash ----------
    def add_item(self):
        self._item_editor(None)

    def edit_items(self):
        win = tk.Toplevel(self.root)
        win.title("Checklistni tahrirlash")
        win.configure(bg=self.COL_BG)
        win.geometry("460x420")
        win.attributes("-topmost", True)

        lb = tk.Listbox(win, bg=self.COL_CARD, fg=self.COL_TXT, font=("Segoe UI", 10),
                        selectbackground=self.COL_GREEN, activestyle="none")
        lb.pack(fill="both", expand=True, padx=10, pady=10)

        def refill():
            lb.delete(0, tk.END)
            for it in self.cfg["items"]:
                tag = "AUTO:" + it["rule"] if it["rule"] != "manual" else "QO'L"
                lb.insert(tk.END, f"[{tag}]  {it['text']}")

        refill()

        def do_edit():
            sel = lb.curselection()
            if sel:
                self._item_editor(sel[0], on_done=refill)

        def do_del():
            sel = lb.curselection()
            if sel:
                del self.cfg["items"][sel[0]]
                save_config(self.cfg)
                refill()
                self._render_items()

        def do_up():
            sel = lb.curselection()
            if sel and sel[0] > 0:
                i = sel[0]
                self.cfg["items"][i-1], self.cfg["items"][i] = self.cfg["items"][i], self.cfg["items"][i-1]
                save_config(self.cfg); refill(); self._render_items()
                lb.selection_set(i-1)

        def do_down():
            sel = lb.curselection()
            if sel and sel[0] < len(self.cfg["items"]) - 1:
                i = sel[0]
                self.cfg["items"][i+1], self.cfg["items"][i] = self.cfg["items"][i], self.cfg["items"][i+1]
                save_config(self.cfg); refill(); self._render_items()
                lb.selection_set(i+1)

        bar = tk.Frame(win, bg=self.COL_BG); bar.pack(fill="x", padx=10, pady=(0, 10))
        ttk.Button(bar, text="Tahrir", command=do_edit).pack(side="left", expand=True, fill="x", padx=2)
        ttk.Button(bar, text="O'chir", command=do_del).pack(side="left", expand=True, fill="x", padx=2)
        ttk.Button(bar, text="▲", command=do_up, width=3).pack(side="left", padx=2)
        ttk.Button(bar, text="▼", command=do_down, width=3).pack(side="left", padx=2)

    def _item_editor(self, index, on_done=None):
        win = tk.Toplevel(self.root)
        win.title("Element" if index is not None else "Yangi element")
        win.configure(bg=self.COL_BG)
        win.geometry("420x220")
        win.attributes("-topmost", True)

        existing = self.cfg["items"][index] if index is not None else {"text": "", "rule": "manual"}

        tk.Label(win, text="Matn:", bg=self.COL_BG, fg=self.COL_TXT).pack(anchor="w", padx=12, pady=(12, 2))
        e_text = tk.Entry(win, width=48)
        e_text.insert(0, existing.get("text", ""))
        e_text.pack(padx=12, fill="x")

        tk.Label(win, text="Avtomatik manba (qoida):", bg=self.COL_BG, fg=self.COL_TXT).pack(anchor="w", padx=12, pady=(12, 2))
        rule_var = tk.StringVar(value=existing.get("rule", "manual"))
        rule_names = list(RULES.keys())
        cmb = ttk.Combobox(win, values=rule_names, textvariable=rule_var, state="readonly")
        cmb.pack(padx=12, fill="x")
        hint = tk.Label(win, text=RULES[rule_var.get()][0], bg=self.COL_BG, fg=self.COL_GRAY,
                        font=("Segoe UI", 8))
        hint.pack(anchor="w", padx=12, pady=(2, 0))
        cmb.bind("<<ComboboxSelected>>", lambda e: hint.config(text=RULES[rule_var.get()][0]))

        def save():
            text = e_text.get().strip()
            if not text:
                messagebox.showwarning("Bo'sh", "Matn kiriting.")
                return
            data = {"text": text, "rule": rule_var.get(), "checked": existing.get("checked", False)}
            if index is not None:
                self.cfg["items"][index] = data
            else:
                self.cfg["items"].append(data)
            save_config(self.cfg)
            self._render_items()
            if on_done:
                on_done()
            win.destroy()

        ttk.Button(win, text="Saqlash", command=save).pack(pady=14)

    # ---------- monitoring (avtomatik) ----------
    def start_monitor(self):
        self.stop_monitor()
        self.monitor_stop.clear()
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()

    def stop_monitor(self):
        self.monitor_stop.set()
        self.monitor_thread = None

    def _monitor_loop(self):
        while not self.monitor_stop.is_set():
            self._poll_once()
            self.monitor_stop.wait(max(1, int(self.cfg.get("poll_seconds", 3))))

    def _poll_once(self):
        path = self.cfg.get("data_file")
        if not path or not os.path.exists(path):
            self.root.after(0, lambda: self._set_conn(False, "fayl topilmadi"))
            return
        try:
            mtime = os.path.getmtime(path)
            with open(path, "r", encoding="utf-8-sig") as f:
                data = json.load(f)
        except Exception as e:
            self.root.after(0, lambda: self._set_conn(False, f"o'qib bo'lmadi"))
            return
        self.last_data = data
        self.last_data_mtime = mtime
        self.root.after(0, lambda: self._apply_auto(data))

    def _apply_auto(self, data):
        self._set_conn(True, data.get("symbol", ""))
        all_ready = True
        any_auto = False
        for var, status, item in self.item_widgets:
            rule = item.get("rule", "manual")
            if rule == "manual":
                if not var.get():
                    all_ready = False
                status.config(text="QO'L", fg=self.COL_GRAY)
                continue
            any_auto = True
            fn = RULES.get(rule, RULES["manual"])[1]
            ok, note = fn(data)
            if ok is None:
                status.config(text="QO'L", fg=self.COL_GRAY)
                continue
            var.set(bool(ok))
            item["checked"] = bool(ok)
            status.config(text=(note[:8] if note else ("OK" if ok else "-")),
                          fg=(self.COL_GREEN if ok else self.COL_RED))
            if not ok:
                all_ready = False
        save_config(self.cfg)
        self._update_ready_dot(all_ready)
        # ALERT — barcha shart tayyor bo'lsa bir marta
        if any_auto and all_ready and not self.alerted:
            self.alerted = True
            self._fire_alert(data)
        if not all_ready:
            self.alerted = False

    def _fire_alert(self, data):
        if self.cfg.get("sound_alert", True):
            beep()
        sym = data.get("symbol", "")
        kz = data.get("killzone", "")
        mss = data.get("mss", "")
        messagebox.showinfo("✅ SETUP TAYYOR",
            f"Barcha shartlar bajarildi!\n\n"
            f"Symbol: {sym}\nKillzone: {kz}\nMSS: {mss}\n\n"
            f"Endi OTE/Breaker entryni va RR>=1:2 ni qo'lda tasdiqlang.")

    # ---------- status ko'rsatish ----------
    def _set_conn(self, connected, note=""):
        if connected:
            self.dot.config(fg=self.COL_GREEN)
            self.status_line.config(text=f"Auto: ulangan  ·  {note}", fg=self.COL_GREEN)
        else:
            self.dot.config(fg=self.COL_RED)
            self.status_line.config(text=f"Auto: {note}", fg=self.COL_RED)

    def _refresh_status_display(self):
        if not self.cfg.get("auto_enabled"):
            self.dot.config(fg=self.COL_GRAY)
            self.status_line.config(text="Auto: o'chiq (qo'lda rejim)", fg=self.COL_GRAY)
        else:
            self.status_line.config(text="Auto: kutilyapti...", fg=self.COL_GRAY)
        self._update_ready_dot()

    def _update_ready_dot(self, all_ready=None):
        if all_ready is None:
            all_ready = all(v.get() for v, _, _ in self.item_widgets) and bool(self.item_widgets)
        # sarlavha dot rangini o'zgartirmaymiz agar auto ulangan bo'lsa
        if not self.cfg.get("auto_enabled"):
            self.dot.config(fg=(self.COL_GREEN if all_ready else self.COL_GRAY))

    def on_close(self):
        self.stop_monitor()
        save_config(self.cfg)
        self.root.destroy()


def main():
    root = tk.Tk()
    ChecklistApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
