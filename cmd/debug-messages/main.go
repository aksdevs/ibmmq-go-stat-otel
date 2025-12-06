package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/aksdevs/ibmmq-go-stat-otel/pkg/config"
	"github.com/aksdevs/ibmmq-go-stat-otel/pkg/mqclient"
	"github.com/sirupsen/logrus"
)

func main() {
	configPath := flag.String("config", "configs/default.yaml", "Configuration file path")
	flag.Parse()

	// Load configuration
	cfg, err := config.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Create logger
	logger := logrus.New()
	logger.SetLevel(logrus.DebugLevel)
	logger.SetOutput(os.Stdout)

	// Connect to MQ
	client, err := mqclient.New(cfg.MQ, logger)
	if err != nil {
		log.Fatalf("Failed to connect to MQ: %v", err)
	}
	defer client.Close()

	fmt.Println("=== IBM MQ Message Debugger ===")
	fmt.Println()

	// Get messages from statistics queue
	fmt.Println("Reading from SYSTEM.ADMIN.STATISTICS.QUEUE...")
	statsMessages, err := client.GetMessagesFromQueue("SYSTEM.ADMIN.STATISTICS.QUEUE", 100)
	if err != nil {
		log.Fatalf("Failed to read statistics: %v", err)
	}

	fmt.Printf("Got %d messages from statistics queue\n", len(statsMessages))
	fmt.Println()

	for i, msg := range statsMessages {
		fmt.Printf("Message %d: %d bytes\n", i+1, len(msg.Data))
		// Print first 100 bytes as hex
		if len(msg.Data) > 0 {
			fmt.Printf("  First 100 bytes (hex): ")
			maxBytes := len(msg.Data)
			if maxBytes > 100 {
				maxBytes = 100
			}
			for j := 0; j < maxBytes; j++ {
				fmt.Printf("%02x ", msg.Data[j])
				if (j+1)%16 == 0 {
					fmt.Printf("\n  ")
				}
			}
			fmt.Println()
		}
	}

	fmt.Println()
	fmt.Println("Reading from SYSTEM.ADMIN.ACCOUNTING.QUEUE...")
	acctMessages, err := client.GetMessagesFromQueue("SYSTEM.ADMIN.ACCOUNTING.QUEUE", 100)
	if err != nil {
		log.Fatalf("Failed to read accounting: %v", err)
	}

	fmt.Printf("Got %d messages from accounting queue\n", len(acctMessages))
}
