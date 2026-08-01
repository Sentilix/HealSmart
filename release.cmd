@echo off

set ADDONNAME=HeroStats

echo Version number (a.b.c) [Q=quit]
set /p VERSION=%ADDONNAME%-
if "%VERSION%"=="q" goto quit
if "%VERSION%"=="Q" goto quit

set BASE=%~dp0
set ZIP=F:\Program Files\7-Zip
set DEST=%TEMP%\%ADDONNAME%

call :subCreateTempDir

rem xcopy %ADDONNAME%\images\* "%DEST%\images\" /S
rem xcopy "%ADDONNAME%\libs" "%DEST%\libs\" /S

copy %ADDONNAME%\*.md "%DEST%\"
copy %ADDONNAME%\*.lua "%DEST%\"
copy %ADDONNAME%\*.toc "%DEST%\" /Y
"%ZIP%\7z.exe" a -tzip Releases\%ADDONNAME%-%VERSION%.zip "%DEST%"

goto ok


rem 
:subCreateTempDir
if not exist "%DEST%" goto subCreateTempDir_noDel
rmdir /S /Q "%DEST%"
:subCreateTempDir_noDel
mkdir "%DEST%"
exit /b


:quit
:ok
echo.
pause







