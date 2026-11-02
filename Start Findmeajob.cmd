@echo off
title Findmeajob
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0findmeajob.ps1" start
if errorlevel 1 (pause) else (timeout /t 4 >nul)
