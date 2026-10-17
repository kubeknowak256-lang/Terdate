@echo off
goto set

:set
set /p "OPR"="Operation (+-*/) > "
set /p "START"="Start > "
set /p "END"="End > "
goto execute

:execute
if "%OPR%"=="+" goto plus
if "%OPR%"=="-" goto minus
if "%OPR%"=="*" goto multi
if "%OPR%"=="/" goto divis

:plus
set /a "eq"=%START+%END%
goto display

:minus
set  /a "eq"=%START%-%END%
goto display

:multi
set /a "eq"=%START%*%END%
goto display

:divis
set /a "eq"=%START%/%END%
goto display

:display
echo.
echo %eq%
pause
exit