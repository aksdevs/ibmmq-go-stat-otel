#!/bin/bash
# IBM MQ Statistics Collector - Quick Start Script
# This script generates test activity and runs the collector

set -e

echo ""
echo "======================================"
echo "IBM MQ Statistics Collector"
echo "Quick Start"
echo "======================================"
echo ""

# Default values
CONFIG_FILE="configs/default.yaml"
MESSAGE_COUNT=100
COLLECTOR_INTERVAL="30s"
PROMETHEUS_PORT=9091

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -m|--messages)
            MESSAGE_COUNT="$2"
            shift 2
            ;;
        -i|--interval)
            COLLECTOR_INTERVAL="$2"
            shift 2
            ;;
        -p|--port)
            PROMETHEUS_PORT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Configuration:"
echo "  Config File: $CONFIG_FILE"
echo "  Messages: $MESSAGE_COUNT"
echo "  Interval: $COLLECTOR_INTERVAL"
echo "  Port: $PROMETHEUS_PORT"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo ""
    echo "Please create a configuration file first:"
    echo "  ./bin/collector config generate > $CONFIG_FILE"
    echo ""
    exit 1
fi

# Generate test activity
echo "Step 1: Generating test activity..."
echo "===================================="
./bin/test-activity -config "$CONFIG_FILE" -messages $MESSAGE_COUNT || {
    echo "Warning: Test activity generation had issues, but continuing with collector..."
}

echo ""
echo "Step 2: Starting IBM MQ Statistics Collector..."
echo "=================================================="
echo ""
echo "Collector is running. Press Ctrl+C to stop."
echo ""
echo "Metrics available at: http://localhost:$PROMETHEUS_PORT/metrics"
echo ""

# Start the collector in continuous mode
./bin/collector -config "$CONFIG_FILE" -continuous -interval $COLLECTOR_INTERVAL -prometheus-port $PROMETHEUS_PORT

echo ""
echo "Collector stopped."
