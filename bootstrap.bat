@echo off
setlocal

if "%BACKEND%" == "" set BACKEND=ninja
if "%DC%" == "" set DC=dmd

if exist bin rmdir /s /q bin

echo Compiling reggae with dub
dub build --compiler="%DC%" || exit /b

cd bin || exit /b

echo Running bootstrapped reggae with backend %BACKEND%
reggae -b "%BACKEND%" --dc="%DC%" .. || exit /b
%BACKEND% %* || exit /b
