@echo off
:loop
cls
set "T=%time: =0%"
echo %date% %T:~0,5%
echo.
echo Press 'Q' to close the program
choice /c QN /d N /t 1 /n >nul
if errorlevel 2 goto loop
exit