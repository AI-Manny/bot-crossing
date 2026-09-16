@echo off
rem Bot Crossing -- always-on runner. Keeps the server up; restarts it if it dies.
cd /d "%~dp0"
if "%PORT%"=="" set PORT=5274
rem Open / New conversation spawns Windows Terminal running `claude` (the CLI)
rem instead of the claude:// desktop deep link. server/api.mjs reads this at
rem startup, so it must be set here -- `npm run dev` sets it separately.
if "%BOT_CROSSING_OPEN%"=="" set BOT_CROSSING_OPEN=cli

if not exist "dist\index.html" (
  echo [%date% %time%] no dist, building... >> "%~dp0bot-crossing.log"
  call npm.cmd run build >> "%~dp0bot-crossing.log" 2>&1
)

:loop
echo [%date% %time%] starting server on port %PORT% >> "%~dp0bot-crossing.log"
node server\serve.mjs >> "%~dp0bot-crossing.log" 2>&1
echo [%date% %time%] server exited (code %errorlevel%), restarting in 5s >> "%~dp0bot-crossing.log"
timeout /t 5 /nobreak >nul
goto loop
