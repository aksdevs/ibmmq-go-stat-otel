package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"time"

	"github.com/aksdevs/ibmmq-go-stat-otel/pkg/config"
	"github.com/sirupsen/logrus"
)

func main() {
	configPath := flag.String("config", "configs/default.yaml", "Configuration file path")
	messageCount := flag.Int("messages", 100, "Number of test messages to send")
	testQueue := flag.String("queue", "TEST.QUEUE", "Test queue name")
	flag.Parse()

	// Load configuration
	cfg, err := config.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		log.Fatalf("Configuration validation failed: %v", err)
	}

	// Create logger
	logger := logrus.New()
	logger.SetLevel(logrus.InfoLevel)

	fmt.Println("=== IBM MQ Test Activity Generator (MQSC) ===")
	fmt.Printf("Queue Manager: %s\n", cfg.MQ.QueueManager)
	fmt.Printf("Connection: %s via %s\n", cfg.MQ.GetConnectionName(), cfg.MQ.Channel)
	fmt.Printf("Test Queue: %s\n", *testQueue)
	fmt.Printf("Message Count: %d\n", *messageCount)
	fmt.Println()

	// Step 1: Create test queue if it doesn't exist
	fmt.Println("Step 1: Creating test queue...")
	err = executeMQSC(cfg.MQ.QueueManager, fmt.Sprintf("DEFINE QLOCAL(%s) REPLACE STATQ(ON)", *testQueue))
	if err != nil {
		log.Fatalf("Failed to create queue: %v", err)
	}
	fmt.Println("✓ Queue created/verified")
	fmt.Println()

	// Step 2: Enable statistics and accounting collection at queue manager level
	fmt.Println("Step 2: Enabling MQ statistics and accounting...")
	err = executeMQSC(cfg.MQ.QueueManager, `ALTER QMGR STATMQI(ON)
ALTER QMGR STATQ(ON)
ALTER QMGR STATCHL(LOW)
ALTER QMGR STATINT(10)
ALTER QMGR ACCTMQI(ON)
ALTER QMGR ACCTQ(ON)`)
	if err != nil {
		log.Fatalf("Failed to enable statistics: %v", err)
	}
	fmt.Println("✓ Statistics and accounting enabled at QMgr level")
	fmt.Println()

	// Step 2b: Enable queue-specific statistics and accounting
	fmt.Println("Step 2b: Enabling queue-specific statistics and accounting...")
	err = executeMQSC(cfg.MQ.QueueManager, fmt.Sprintf("ALTER QLOCAL(%s) STATQ(ON) ACCTQ(ON)", *testQueue))
	if err != nil {
		log.Fatalf("Failed to enable queue statistics: %v", err)
	}
	fmt.Println("✓ Queue-specific statistics and accounting enabled")
	fmt.Println()

	// Step 3: Generate test activity using PowerShell amqsput
	fmt.Printf("Step 3: Sending %d test messages using amqsput...\n", *messageCount)
	for i := 1; i <= *messageCount; i++ {
		if i%10 == 0 {
			fmt.Printf("  Sent %d/%d messages...\n", i, *messageCount)
		}

		message := fmt.Sprintf("Test Message %d - %s\n", i, time.Now().Format(time.RFC3339Nano))
		err := executeAmqsPut(cfg.MQ.QueueManager, *testQueue, message)
		if err != nil {
			fmt.Printf("Warning: Failed to send message %d: %v\n", i, err)
		}
		time.Sleep(10 * time.Millisecond)
	}
	fmt.Println("✓ PUT messages completed")
	fmt.Println()

	// Step 4: Generate GET activity
	getCount := *messageCount / 2
	if getCount > 50 {
		getCount = 50
	}
	fmt.Printf("Step 4: Getting %d messages to generate GET activity...\n", getCount)
	for i := 1; i <= getCount; i++ {
		if i%10 == 0 {
			fmt.Printf("  Retrieved %d/%d messages...\n", i, getCount)
		}
		executeAmqsGet(cfg.MQ.QueueManager, *testQueue)
		time.Sleep(10 * time.Millisecond)
	}
	fmt.Println("✓ GET activity completed")
	fmt.Println()

	// Step 5: Display queue statistics
	fmt.Println("Step 5: Displaying queue statistics...")
	mqscCommands := fmt.Sprintf(`DISPLAY QSTATUS(%s) ALL
DISPLAY QLOCAL(%s)`, *testQueue, *testQueue)
	err = executeMQSC(cfg.MQ.QueueManager, mqscCommands)
	if err != nil {
		fmt.Printf("Warning: Failed to display queue status: %v\n", err)
	}
	fmt.Println()

	fmt.Println("=== Test Activity Generation Complete ===")
	fmt.Println("The MQ system has been activated with:")
	fmt.Printf("  - %d PUT operations\n", *messageCount)
	fmt.Printf("  - ~%d GET operations\n", getCount)
	fmt.Println()
	fmt.Println("Now run the collector to collect statistics:")
	fmt.Println("  ./collector --continuous --interval=30s")
	fmt.Println()
	fmt.Println("View metrics at: http://localhost:9091/metrics")
}

// executeMQSC executes MQSC commands
func executeMQSC(queueManager, commands string) error {
	cmd := exec.Command("cmd", "/c", fmt.Sprintf("echo %s | runmqsc.exe %s", commands, queueManager))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// executeAmqsPut sends a message using amqsput
func executeAmqsPut(queueManager, queueName, message string) error {
	cmd := exec.Command("cmd", "/c", fmt.Sprintf("echo %s | amqsput.exe %s %s", message, queueName, queueManager))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// executeAmqsGet gets a message using amqsget
func executeAmqsGet(queueManager, queueName string) error {
	cmd := exec.Command("amqsget.exe", queueName, queueManager)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
