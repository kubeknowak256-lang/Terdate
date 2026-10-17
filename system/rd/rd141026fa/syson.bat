@echo on

:cd
>"%~dp0system\temp\cd.txt" echo %CD%
set /p "CDS=" <"%~dp0system\temp\cd.txt"
echo CD=%CDS%
set /p "CDW=set cds (y/n)> "
if /I "%CDW%"=="y" goto setcds
if /I "%CDW%"=="n" goto load
echo ERROR
goto cd

:setcds
set /p "CDS=set-cds> "
>"%~dp0system\temp\cd.txt" echo %CDS%
goto load

:load
start "" "%~dp0system\terminal.bat"
exit