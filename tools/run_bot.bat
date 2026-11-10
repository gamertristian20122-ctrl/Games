@echo off
rem Plays automatic test runs with the bot and writes docs\balance_report.md.
rem
rem   Double-click this file, or run it from a command prompt:
rem     tools\run_bot.bat          30 runs for each of the three skill levels
rem     tools\run_bot.bat 100      100 runs each
rem
rem If Windows says it cannot find "godot", tell it where Godot is first.
rem Use the file whose name ends in _console.exe, for example:
rem     set GODOT=C:\Godot\Godot_v4.7.2-stable_win64_console.exe

setlocal
cd /d "%~dp0\.."
if "%GODOT%"=="" set GODOT=godot
set RUNS=%1
if "%RUNS%"=="" set RUNS=30

if exist bot_out rmdir /s /q bot_out
mkdir bot_out

for %%S in (new ok pro) do (
	echo Playing %RUNS% runs at skill %%S ...
	"%GODOT%" --headless --fixed-fps 60 --path . -- --bot --skill=%%S --runs=%RUNS% --seed=1 --out=bot_out/%%S.json
)
"%GODOT%" --headless --path . -- --report=bot_out --out=docs/balance_report.md
echo.
echo Done. Open docs\balance_report.md
pause
