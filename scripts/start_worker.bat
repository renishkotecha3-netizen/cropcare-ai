@echo off
cd /d "%~dp0..\backend"
call .venv\Scripts\activate.bat
python manage.py process_notifications --watch
pause
