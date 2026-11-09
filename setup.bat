@echo off
chcp 65001 >nul
title Настройка BG3 Launcher
echo.
echo  ============================================
echo    НАСТРОЙКА BG3 LAUNCHER
echo  ============================================
echo.
echo  Программа сама попробует найти Teams, Radmin,
echo  игру и трейнер. По окончании появится окно
echo  с результатом - его и смотри.
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_app\autodetect.ps1" 2>"%~dp0_app\setup_error.txt"

rem Если PowerShell упал с ошибкой - показываем её и ждём
if errorlevel 1 (
    echo.
    echo  [ОШИБКА] Что-то пошло не так. Текст ошибки:
    echo  ------------------------------------------------------------
    type "%~dp0_app\setup_error.txt"
    echo  ------------------------------------------------------------
    echo  Пришли этот текст тому, кто дал тебе лаунчер.
)

echo.
echo  Если окошко с результатом уже показалось - можно закрыть.
echo.
pause
