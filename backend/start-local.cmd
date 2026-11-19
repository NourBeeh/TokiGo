@echo off
REM TokiGo backend - one-shot local launcher (Windows).
REM Starts the throwaway local PostgreSQL, sets the dev environment and runs
REM the backend. No secrets here: these are local-only dev values.
setlocal

set PG_BIN=C:\Users\mnour\AppData\Local\Temp\pg\pgsql\bin
set PG_DATA=C:\Users\mnour\AppData\Local\Temp\pgdata
set PG_LOG=C:\Users\mnour\AppData\Local\Temp\pg.log

REM 1) PostgreSQL (safe to call when it is already running).
"%PG_BIN%\pg_ctl.exe" -D "%PG_DATA%" -l "%PG_LOG%" -o "-p 5432" start
timeout /t 2 /nobreak >nul

REM 2) Environment (.env is intentionally left untouched).
set NODE_ENV=development
set DB_HOST=127.0.0.1
set DB_PORT=5432
set DB_USER=tokigo
set DB_PASSWORD=tokigo
set DB_NAME=tokigo
set WEBHOOK_SIGNING_KEY=dev_only_signing_key
set GOOGLE_CLIENT_ID=423433597936-erj0nejep60cs5g84s4goknhis6v8jle.apps.googleusercontent.com

REM 3) Backend.
cd /d "%~dp0"
echo Starting TokiGo backend on http://0.0.0.0:3000 ...
npm.cmd run start:dev

endlocal
