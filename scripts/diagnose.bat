@echo off
REM Diagnostic script for IBM MQ Statistics Collector
REM Verifies all components are in place and working

setlocal enabledelayedexpansion

cls
echo.
echo ======================================
echo IBM MQ Collector - Diagnostic Check
echo ======================================
echo.

REM Color codes
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "RESET=[0m"

REM Check 1: Collector executable
echo [*] Checking collector executable...
if exist bin\collector.exe (
    echo   [OK] bin\collector.exe found
) else (
    echo   [ERROR] bin\collector.exe not found
    echo   Build with: go build -o bin\collector.exe .\cmd\collector
    set /a error_count+=1
)

REM Check 2: Test activity executable
echo [*] Checking test-activity executable...
if exist bin\test-activity.exe (
    echo   [OK] bin\test-activity.exe found
) else (
    echo   [ERROR] bin\test-activity.exe not found
    echo   Build with: go build -o bin\test-activity.exe .\cmd\test-activity
    set /a error_count+=1
)

REM Check 3: Configuration file
echo [*] Checking configuration file...
if exist configs\default.yaml (
    echo   [OK] configs\default.yaml found
) else (
    echo   [WARNING] configs\default.yaml not found
    echo   Generate with: .\bin\collector.exe config generate ^> configs\default.yaml
    set /a warning_count+=1
)

REM Check 4: Scripts
echo [*] Checking helper scripts...
if exist scripts\run-collector.bat (
    echo   [OK] scripts\run-collector.bat found
) else (
    echo   [WARNING] scripts\run-collector.bat not found
    set /a warning_count+=1
)

if exist scripts\generate-test-activity.ps1 (
    echo   [OK] scripts\generate-test-activity.ps1 found
) else (
    echo   [WARNING] scripts\generate-test-activity.ps1 not found
    set /a warning_count+=1
)

REM Check 5: Go installation
echo [*] Checking Go installation...
where go >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%A in ('go version') do (
        echo   [OK] %%A
    )
) else (
    echo   [ERROR] Go not found in PATH
    set /a error_count+=1
)

REM Check 6: Documentation
echo [*] Checking documentation...
if exist GETTING_STARTED.md (
    echo   [OK] GETTING_STARTED.md found
) else (
    echo   [WARNING] GETTING_STARTED.md not found
    set /a warning_count+=1
)

if exist METRICS_COVERAGE.md (
    echo   [OK] METRICS_COVERAGE.md found
) else (
    echo   [WARNING] METRICS_COVERAGE.md not found
    set /a warning_count+=1
)

if exist QUICK_REFERENCE.md (
    echo   [OK] QUICK_REFERENCE.md found
) else (
    echo   [WARNING] QUICK_REFERENCE.md not found
    set /a warning_count+=1
)

REM Check 7: Source files
echo [*] Checking source files...
if exist cmd\collector\main.go (
    echo   [OK] cmd\collector\main.go found
) else (
    echo   [ERROR] cmd\collector\main.go not found
    set /a error_count+=1
)

if exist pkg\pcf\parser.go (
    echo   [OK] pkg\pcf\parser.go found
) else (
    echo   [ERROR] pkg\pcf\parser.go not found
    set /a error_count+=1
)

if exist pkg\prometheus\collector.go (
    echo   [OK] pkg\prometheus\collector.go found
) else (
    echo   [ERROR] pkg\prometheus\collector.go not found
    set /a error_count+=1
)

REM Check 8: Test execution
echo [*] Running tests...
go test -v ./pkg/pcf -timeout 30s >nul 2>&1
if !errorlevel! equ 0 (
    echo   [OK] Tests passed
) else (
    echo   [WARNING] Some tests failed (see output above)
    set /a warning_count+=1
)

REM Summary
echo.
echo ======================================
echo Diagnostic Summary
echo ======================================
echo.

if defined error_count (
    echo [ERRORS] !error_count! critical issues found
) else (
    echo [OK] No critical errors
)

if defined warning_count (
    echo [WARNINGS] !warning_count! issues found (non-critical)
) else (
    echo [OK] No warnings
)

echo.
echo ======================================
echo Next Steps
echo ======================================
echo.
echo 1. Generate configuration:
echo    .\bin\collector.exe config generate ^> configs\default.yaml
echo.
echo 2. Edit configs\default.yaml with your MQ connection details
echo.
echo 3. Generate test activity:
echo    .\bin\test-activity.exe -config configs\default.yaml -messages 100
echo.
echo 4. Run the collector:
echo    .\bin\collector.exe -config configs\default.yaml -continuous
echo.
echo 5. View metrics at:
echo    http://localhost:9091/metrics
echo.
echo For more details, see GETTING_STARTED.md
echo.

endlocal
