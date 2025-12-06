@echo off
REM IBM MQ Statistics Collector - Quick Start Script
REM This script generates test activity and runs the collector

setlocal enabledelayedexpansion

echo.
echo ======================================
echo IBM MQ Statistics Collector
echo Quick Start
echo ======================================
echo.

REM Parse command line arguments
set CONFIG_FILE=configs/default.yaml
set MESSAGE_COUNT=100
set COLLECTOR_INTERVAL=30s
set PROMETHEUS_PORT=9091

:parse_args
if "%1"=="" goto args_done
if /i "%1"=="-c" (
    set CONFIG_FILE=%2
    shift
    shift
    goto parse_args
)
if /i "%1"=="-m" (
    set MESSAGE_COUNT=%2
    shift
    shift
    goto parse_args
)
if /i "%1"=="-i" (
    set COLLECTOR_INTERVAL=%2
    shift
    shift
    goto parse_args
)
if /i "%1"=="-p" (
    set PROMETHEUS_PORT=%2
    shift
    shift
    goto parse_args
)
shift
goto parse_args

:args_done
echo Configuration:
echo   Config File: !CONFIG_FILE!
echo   Messages: !MESSAGE_COUNT!
echo   Interval: !COLLECTOR_INTERVAL!
echo   Port: !PROMETHEUS_PORT!
echo.

REM Check if config file exists
if not exist "!CONFIG_FILE!" (
    echo Error: Configuration file not found: !CONFIG_FILE!
    echo.
    echo Please create a configuration file first:
    echo   .\bin\collector.exe config generate ^> !CONFIG_FILE!
    echo.
    exit /b 1
)

REM Generate test activity
echo Step 1: Generating test activity...
echo ====================================
.\bin\test-activity.exe -config "!CONFIG_FILE!" -messages !MESSAGE_COUNT!
if errorlevel 1 (
    echo Warning: Test activity generation had issues, but continuing with collector...
)

echo.
echo Step 2: Starting IBM MQ Statistics Collector...
echo ==================================================
echo.
echo Collector is running. Press Ctrl+C to stop.
echo.
echo Metrics available at: http://localhost:!PROMETHEUS_PORT!/metrics
echo.

REM Start the collector in continuous mode
.\bin\collector.exe -config "!CONFIG_FILE!" -continuous -interval !COLLECTOR_INTERVAL! -prometheus-port !PROMETHEUS_PORT!

echo.
echo Collector stopped.
