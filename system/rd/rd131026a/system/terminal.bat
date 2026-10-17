@echo off
set /p "CDS"=<"%~dp0system\temp\cd.txt"
echo Welcome to Terdate Operating System
echo version rd131026a
goto comm

:comm
set /p "COMM=%CDS%> "
if "%COMM%"=="cls" (
   cls
)
if "%COMM%"=="program" goto prgopen
if "%COMM%"=="shutdown" goto shutdown
if "%COMM%"=="programl" (
   echo Calculator
   echo Clock
)
goto comm

:shutdown
set "SHT="
set /p "SHT=Shutdown? (y/n)> "
if "%SHT%"=="y" (
   start "" "%~dp0sysoff.bat"
   exit
)
if "%SHT%"=="n" goto comm
goto shutdown

:prgopen
set "PRGO="
set /p "PRGO=What program do you want to open? (Calculator, Clock)> "
if "%PRGO%"=="Clock" start "" "%CDS%\programs\clock.bat"
if "%PRGO%"=="Calculator" start "" "%CDS%\programs\calc.bat"
goto comm