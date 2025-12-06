#!/bin/bash
# Diagnostic script for IBM MQ Statistics Collector
# Verifies all components are in place and working

set +e

clear

echo ""
echo "======================================"
echo "IBM MQ Collector - Diagnostic Check"
echo "======================================"
echo ""

error_count=0
warning_count=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Collector executable
echo "[*] Checking collector executable..."
if [ -f bin/collector ]; then
    echo -e "   ${GREEN}[OK]${NC} bin/collector found"
else
    echo -e "   ${RED}[ERROR]${NC} bin/collector not found"
    echo "   Build with: go build -o bin/collector ./cmd/collector"
    ((error_count++))
fi

# Check 2: Test activity executable
echo "[*] Checking test-activity executable..."
if [ -f bin/test-activity ]; then
    echo -e "   ${GREEN}[OK]${NC} bin/test-activity found"
else
    echo -e "   ${RED}[ERROR]${NC} bin/test-activity not found"
    echo "   Build with: go build -o bin/test-activity ./cmd/test-activity"
    ((error_count++))
fi

# Check 3: Configuration file
echo "[*] Checking configuration file..."
if [ -f configs/default.yaml ]; then
    echo -e "   ${GREEN}[OK]${NC} configs/default.yaml found"
else
    echo -e "   ${YELLOW}[WARNING]${NC} configs/default.yaml not found"
    echo "   Generate with: ./bin/collector config generate > configs/default.yaml"
    ((warning_count++))
fi

# Check 4: Scripts
echo "[*] Checking helper scripts..."
if [ -f scripts/run-collector.sh ]; then
    echo -e "   ${GREEN}[OK]${NC} scripts/run-collector.sh found"
else
    echo -e "   ${YELLOW}[WARNING]${NC} scripts/run-collector.sh not found"
    ((warning_count++))
fi

if [ -f scripts/generate-test-activity.ps1 ]; then
    echo -e "   ${GREEN}[OK]${NC} scripts/generate-test-activity.ps1 found"
else
    echo -e "   ${YELLOW}[WARNING]${NC} scripts/generate-test-activity.ps1 not found"
    ((warning_count++))
fi

# Check 5: Go installation
echo "[*] Checking Go installation..."
if command -v go &> /dev/null; then
    go_version=$(go version)
    echo -e "   ${GREEN}[OK]${NC} $go_version"
else
    echo -e "   ${RED}[ERROR]${NC} Go not found in PATH"
    ((error_count++))
fi

# Check 6: Documentation
echo "[*] Checking documentation..."
if [ -f GETTING_STARTED.md ]; then
    echo -e "   ${GREEN}[OK]${NC} GETTING_STARTED.md found"
else
    echo -e "   ${YELLOW}[WARNING]${NC} GETTING_STARTED.md not found"
    ((warning_count++))
fi

if [ -f METRICS_COVERAGE.md ]; then
    echo -e "   ${GREEN}[OK]${NC} METRICS_COVERAGE.md found"
else
    echo -e "   ${YELLOW}[WARNING]${NC} METRICS_COVERAGE.md not found"
    ((warning_count++))
fi

if [ -f QUICK_REFERENCE.md ]; then
    echo -e "   ${GREEN}[OK]${NC} QUICK_REFERENCE.md found"
else
    echo -e "   ${YELLOW}[WARNING]${NC} QUICK_REFERENCE.md not found"
    ((warning_count++))
fi

# Check 7: Source files
echo "[*] Checking source files..."
if [ -f cmd/collector/main.go ]; then
    echo -e "   ${GREEN}[OK]${NC} cmd/collector/main.go found"
else
    echo -e "   ${RED}[ERROR]${NC} cmd/collector/main.go not found"
    ((error_count++))
fi

if [ -f pkg/pcf/parser.go ]; then
    echo -e "   ${GREEN}[OK]${NC} pkg/pcf/parser.go found"
else
    echo -e "   ${RED}[ERROR]${NC} pkg/pcf/parser.go not found"
    ((error_count++))
fi

if [ -f pkg/prometheus/collector.go ]; then
    echo -e "   ${GREEN}[OK]${NC} pkg/prometheus/collector.go found"
else
    echo -e "   ${RED}[ERROR]${NC} pkg/prometheus/collector.go not found"
    ((error_count++))
fi

# Check 8: Test execution
echo "[*] Running quick test..."
if go test -v ./pkg/pcf -timeout 30s &>/dev/null; then
    echo -e "   ${GREEN}[OK]${NC} Tests passed"
else
    echo -e "   ${YELLOW}[WARNING]${NC} Some tests failed or timed out"
    ((warning_count++))
fi

# Summary
echo ""
echo "======================================"
echo "Diagnostic Summary"
echo "======================================"
echo ""

if [ $error_count -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} No critical errors"
else
    echo -e "${RED}[ERRORS]${NC} $error_count critical issue(s) found"
fi

if [ $warning_count -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} No warnings"
else
    echo -e "${YELLOW}[WARNINGS]${NC} $warning_count issue(s) found (non-critical)"
fi

echo ""
echo "======================================"
echo "Next Steps"
echo "======================================"
echo ""
echo "1. Generate configuration:"
echo "   ./bin/collector config generate > configs/default.yaml"
echo ""
echo "2. Edit configs/default.yaml with your MQ connection details"
echo ""
echo "3. Generate test activity:"
echo "   ./bin/test-activity -config configs/default.yaml -messages 100"
echo ""
echo "4. Run the collector:"
echo "   ./bin/collector -config configs/default.yaml -continuous"
echo ""
echo "5. View metrics at:"
echo "   http://localhost:9091/metrics"
echo ""
echo "For more details, see GETTING_STARTED.md"
echo ""
