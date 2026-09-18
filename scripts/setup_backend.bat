@echo off
setlocal
cd /d "%~dp0..\backend"
py -3.12 -m venv .venv
if errorlevel 1 goto failure
call .venv\Scripts\activate.bat
python -m pip install -r requirements.txt
if errorlevel 1 goto failure
if not exist .env (
  copy .env.example .env >nul
  python -c "from pathlib import Path; import secrets; p=Path('.env'); p.write_text(p.read_text().replace('replace-with-a-random-secret-before-deployment', secrets.token_urlsafe(48)))"
)
python manage.py migrate
if errorlevel 1 goto failure
python manage.py check_model
if errorlevel 1 goto failure
echo.
echo Setup complete. Run scripts\start_backend.bat next.
pause
exit /b 0
:failure
echo Setup failed. Read the error above and docs\SETUP_WINDOWS.md.
pause
exit /b 1
