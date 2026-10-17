@echo off
goto set

:set
set /p "OPR=Operation (+-*/) > "
if /i "%OPR%"=="q" exit
set /p "START=Start > "
if /i "%START%"=="q" exit
set /p "END=End > "
if /i "%END%"=="q" exit
goto execute

:execute
if "%OPR%"=="+" goto plus
if "%OPR%"=="-" goto minus
if "%OPR%"=="*" goto multi
if "%OPR%"=="/" goto divis
goto set

:plus
set /a "eq"=%START%+%END%
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