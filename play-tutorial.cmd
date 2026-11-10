@echo off
title Carscape - Tutorial Preview
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Play-Tutorial.ps1"
if errorlevel 1 pause
