@echo off
REM ================================================================
REM  ICT Prop Checklist - .exe yasash (o'z Windows kompyuteringizda)
REM  Talab: Python 3.8+ o'rnatilgan bo'lishi kerak.
REM  Ishga tushirish: shu faylni ikki marta bosing.
REM ================================================================

echo PyInstaller o'rnatilmoqda...
python -m pip install --upgrade pyinstaller
if errorlevel 1 (
    echo XATO: Python topilmadi. Avval Python o'rnating: https://python.org
    pause
    exit /b 1
)

echo.
echo .exe yasalmoqda...
python -m PyInstaller --onefile --windowed --name ICT_Prop_Checklist app.py

echo.
echo TAYYOR! Dastur shu yerda:  dist\ICT_Prop_Checklist.exe
echo config.json .exe yonida saqlanadi.
pause
