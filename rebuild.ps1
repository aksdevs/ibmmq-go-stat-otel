# Stop the collector if running
$collector = Get-Process collector -ErrorAction SilentlyContinue
if ($collector) {
    Write-Host "Stopping collector process..."
    $collector | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Clean and rebuild
Write-Host "Rebuilding collector..."
cd d:\Go\ibmmq-go-stat-otel

# First, clean old binary
if (Test-Path bin\collector.exe) {
    Remove-Item bin\collector.exe -Force
}

# Build collector
go build -o bin\collector.exe cmd\collector\main.go

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful!"
    Get-Item bin\collector.exe | Select-Object -ExpandProperty FullName
} else {
    Write-Host "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
