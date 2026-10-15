@echo on
goto cd

:cd
echo %CD%> "%~dp0system\temp\cd.txt"
for /f "delims=" %%a in ('type "%~dp0system\temp\cd.txt"') do set "CDS=%%a"
set /p "CDS"=<"%~dp0system\temp\cd.txt"
echo CD=%CDS% (%CDS%)
set /p "CDW=set cds (y/n)> "
if "%CDW%"=="y" (
   set /p "CDS=set-cds> "
) else (
   if "%CDW%"=="n" goto load
   echo ERROR
   goto cd
)

:load
start "" "%~dp0system\terminal.bat"
exit