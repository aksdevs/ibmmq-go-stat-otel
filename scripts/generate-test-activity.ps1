# IBM MQ Test Activity Generator
# This script generates test messages and activity on IBM MQ for testing the collector

param(
    [string]$QueueManager = "MQQM1",
    [string]$Channel = "APP1.SVRCONN",
    [string]$ConnectionName = "localhost(1414)",
    [string]$User = "",
    [string]$Password = "",
    [string]$TestQueue = "TEST.QUEUE",
    [int]$MessageCount = 100,
    [int]$DelayMs = 10
)

# Check if IBM MQ command line is available
$mqPath = "C:\Program Files\IBM\MQ\bin64"
if (-not (Test-Path $mqPath)) {
    $mqPath = "C:\Program Files\IBM\MQ\bin"
}

if (-not (Test-Path $mqPath)) {
    Write-Error "IBM MQ client tools not found. Please ensure IBM MQ is installed."
    exit 1
}

# Add MQ tools to PATH
$env:PATH = "$mqPath;$env:PATH"

Write-Host "IBM MQ Test Activity Generator" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Queue Manager: $QueueManager" -ForegroundColor Green
Write-Host "Channel: $Channel" -ForegroundColor Green
Write-Host "Connection: $ConnectionName" -ForegroundColor Green
Write-Host "Test Queue: $TestQueue" -ForegroundColor Green
Write-Host "Messages to send: $MessageCount" -ForegroundColor Green
Write-Host ""

# Step 1: Create test queue if it doesn't exist
Write-Host "Step 1: Creating test queue..." -ForegroundColor Yellow
$mqscContent = @"
DEFINE QLOCAL($TestQueue) REPLACE
"@

$mqscFile = [System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_.Name + ".mqsc" } -PassThru
Set-Content -Path $mqscFile -Value $mqscContent -Encoding ASCII

try {
    $output = & runmqsc.exe -w 10 $QueueManager < $mqscFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "MQSC command had issues:`n$output"
    } else {
        Write-Host "✓ Queue created/verified" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to create queue: $_"
    exit 1
}
finally {
    Remove-Item -Path $mqscFile -Force -ErrorAction SilentlyContinue
}

# Step 2: Enable statistics collection
Write-Host "Step 2: Enabling MQ statistics..." -ForegroundColor Yellow
$mqscContent = @"
ALTER QMGR STATMQI(ON)
ALTER QMGR STATQ(ON)
ALTER QMGR STATCHL(LOW)
"@

$mqscFile = [System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_.Name + ".mqsc" } -PassThru
Set-Content -Path $mqscFile -Value $mqscContent -Encoding ASCII

try {
    $output = & runmqsc.exe -w 10 $QueueManager < $mqscFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "MQSC command had issues:`n$output"
    } else {
        Write-Host "✓ Statistics enabled" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to enable statistics: $_"
    exit 1
}
finally {
    Remove-Item -Path $mqscFile -Force -ErrorAction SilentlyContinue
}

# Step 3: Generate test activity using amqsput (put messages)
Write-Host "Step 3: Generating PUT messages..." -ForegroundColor Yellow

# Create a test message file
$messageFile = [System.IO.Path]::GetTempFileName()
@"
This is a test message for IBM MQ performance testing.
MessageID: {0}
Timestamp: {1}
"@ -f [Guid]::NewGuid().ToString().Substring(0, 8), (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")

for ($i = 1; $i -le $MessageCount; $i++) {
    if ($i % 10 -eq 0) {
        Write-Host "  Sent $i/$MessageCount messages..." -ForegroundColor Cyan
    }
    
    $message = @"
Test Message $i
ID: {0}
Timestamp: {1}
"@ -f [Guid]::NewGuid().ToString().Substring(0, 8), (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    
    # Use echo to pipe message to amqsput
    try {
        $message | & amqsput.exe $TestQueue $QueueManager 2>&1 | Out-Null
    }
    catch {
        Write-Warning "Failed to send message $i : $_"
    }
    
    # Small delay between messages
    if ($DelayMs -gt 0) {
        Start-Sleep -Milliseconds $DelayMs
    }
}

Write-Host "✓ PUT messages completed" -ForegroundColor Green

# Step 4: Generate GET activity
Write-Host "Step 4: Generating GET messages..." -ForegroundColor Yellow

$getCount = [Math]::Min(50, $MessageCount)
for ($i = 1; $i -le $getCount; $i++) {
    if ($i % 10 -eq 0) {
        Write-Host "  Retrieved $i/$getCount messages..." -ForegroundColor Cyan
    }
    
    try {
        & amqsget.exe $TestQueue $QueueManager 2>&1 | Out-Null
    }
    catch {
        Write-Warning "Failed to get message $i : $_"
    }
    
    if ($DelayMs -gt 0) {
        Start-Sleep -Milliseconds $DelayMs
    }
}

Write-Host "✓ GET messages completed" -ForegroundColor Green

# Step 5: Display queue statistics
Write-Host "Step 5: Displaying queue statistics..." -ForegroundColor Yellow

$mqscContent = @"
DISPLAY QSTATUS($TestQueue) ALL
DISPLAY QLOCAL($TestQueue)
"@

$mqscFile = [System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_.Name + ".mqsc" } -PassThru
Set-Content -Path $mqscFile -Value $mqscContent -Encoding ASCII

try {
    Write-Host ""
    & runmqsc.exe -w 10 $QueueManager < $mqscFile
}
catch {
    Write-Error "Failed to display queue status: $_"
}
finally {
    Remove-Item -Path $mqscFile -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Test Activity Generation Complete!" -ForegroundColor Green
Write-Host "The collector should now see statistics and accounting data." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run the collector to collect statistics" -ForegroundColor White
Write-Host "2. Access the metrics at http://localhost:9091/metrics" -ForegroundColor White
