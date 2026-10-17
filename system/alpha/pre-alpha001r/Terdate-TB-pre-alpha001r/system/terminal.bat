@echo off
set "LOGF=%~dp0temp\log.txt"
set /p "CDS=" <"%~dp0temp\cd.txt"
call :log "System started. CDS loaded: %CDS%"
echo Welcome to Terdate Operating System
echo version pre-alpha001r
goto comm

:comm
set "COMM="
set /p "COMM=%CDS%> "
if not defined COMM goto comm
call :log "Command entered: %COMM%"
if /I "%COMM%"=="cls" goto c_cls
if /I "%COMM%"=="program" goto prgopen
if /I "%COMM%"=="shutdown" goto shutdown
if /I "%COMM%"=="programl" goto c_programl
if /I "%COMM%"=="tree" goto c_tree
if /I "%COMM%"=="CDS" goto cds
if /I "%COMM%"=="echo VB" goto evb
if /I "%COMM%"=="echo log" goto c_echolog
if /I "%COMM%"=="clear log" goto c_clearlog
if /I "%COMM%"=="print" goto c_printempty
if /I "%COMM:~0,6%"=="print " goto c_print
call :log "Result: invalid command"
goto comm

:c_print
echo(%COMM:~6%
call :log "Result: OK (text printed)"
goto comm

:c_printempty
echo Usage: print text
call :log "Result: invalid usage (print needs text)"
goto comm

:c_cls
cls
call :log "Result: OK (screen cleared)"
goto comm

:c_programl
echo Calculator
echo Clock
call :log "Result: OK (program list displayed)"
goto comm

:c_tree
tree /f /a "%CDS%"
if errorlevel 1 (
   call :log "Result: ERROR (tree failed for %CDS%)"
) else (
   call :log "Result: OK (tree displayed for %CDS%)"
)
goto comm

:c_echolog
if exist "%LOGF%" (
   type "%LOGF%"
) else (
   echo Log is empty.
)
call :log "Result: OK (log displayed)"
goto comm

:c_clearlog
del "%LOGF%" >nul 2>&1
call :log "Result: OK (log cleared)"
goto comm

:shutdown
set "SHT="
set /p "SHT=Shutdown? (y/n)> "
if /I "%SHT%"=="y" (
   call :log "Result: OK (system shutdown)"
   start "" "%~dp0sysoff.bat"
   exit
)
if /I "%SHT%"=="n" (
   call :log "Result: OK (shutdown cancelled)"
   goto comm
)
call :log "Shutdown answer invalid: %SHT%"
goto shutdown

:prgopen
set "PRGO="
set /p "PRGO=What program do you want to open? (Calculator, Clock)> "
if /I "%PRGO%"=="Clock" (
   start "" "%CDS%\programs\clock.bat"
   call :log "Result: OK (Clock opened)"
   goto comm
)
if /I "%PRGO%"=="Calculator" (
   start "" "%CDS%\programs\calc.bat"
   call :log "Result: OK (Calculator opened)"
   goto comm
)
call :log "Result: invalid program name: %PRGO%"
goto comm

:cds
set /p "CDS=Set cd > "
>"%~dp0temp\cd.txt" echo %CDS%
call :log "Result: OK (CD set to %CDS%)"
goto comm

:evb
set "EVB="
set /p "EVB=What vb to display? > "
if /I "%EVB%"=="CDS" (
   echo %CDS%
   call :log "Result: OK (variable CDS displayed)"
   goto comm
)
call :log "Result: invalid variable name: %EVB%"
goto comm

:log
setlocal
set "T=%time: =0%"
set "MSG=%~1"
setlocal enabledelayedexpansion
>>"%LOGF%" echo [%date% %T:~0,8%] !MSG!
endlocal
endlocal
exit /b