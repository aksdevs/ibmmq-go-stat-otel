package pcf

import (
	"encoding/binary"
	"strings"

	"github.com/sirupsen/logrus"
)

// InquiryHandler sends PCF inquiry commands and parses responses
type InquiryHandler struct {
	logger *logrus.Logger
}

// NewInquiryHandler creates a new inquiry handler
func NewInquiryHandler(logger *logrus.Logger) *InquiryHandler {
	return &InquiryHandler{
		logger: logger,
	}
}

// QueueHandleDetails represents a single queue handle from PCF inquiry
type QueueHandleDetails struct {
	QueueName      string
	ApplicationTag string // e.g., "el\bin\producer-consumer.exe"
	ChannelName    string // e.g., "APP1.SVRCONN"
	ConnectionName string // e.g., "127.0.0.1"
	UserID         string // e.g., "atulk@DESKTOP-2G7OVO3"
	ProcessID      int32  // e.g., 24600
	InputMode      string // "INPUT", "SHARED", "NO"
	OutputMode     string // "OUTPUT", "YES", "NO"
}

// BuildInquireQueueStatusCmd builds a PCF INQUIRE_QUEUE_STATUS command
// This queries queue handle details similar to: DIS QS(queue_name) TYPE(HANDLE) ALL
func (h *InquiryHandler) BuildInquireQueueStatusCmd(queueName string) []byte {
	// PCF Command Format:
	// Offset  Size  Description
	// 0-3     4     Magic "PCF\0" (0x50434600)
	// 4-7     4     Message Type (1 = MQCFT_COMMAND)
	// 8-11    4     Command Code (96 = MQCMD_INQUIRE_QUEUE_STATUS)
	// 12-15   4     Reserved
	// 16-19   4     Parameter Count

	buf := make([]byte, 0, 256)

	// Magic
	buf = append(buf, 0x50, 0x43, 0x46, 0x00) // "PCF\0"

	// Message type
	buf = append(buf, 0x00, 0x00, 0x00, 0x01) // MQCFT_COMMAND

	// Command code
	buf = append(buf, 0x00, 0x00, 0x00, 0x60) // 96 = MQCMD_INQUIRE_QUEUE_STATUS

	// Reserved
	buf = append(buf, 0x00, 0x00, 0x00, 0x00)

	// Parameter count (will be updated)
	paramCountPos := len(buf)
	buf = append(buf, 0x00, 0x00, 0x00, 0x01) // 1 parameter

	// Parameter 1: Queue Name (MQCA_Q_NAME = 2016)
	// Parameter format:
	// Offset  Size  Description
	// 0-3     4     Type (4 = MQCFT_STRING)
	// 4-7     4     Parameter length (including header)
	// 8-11    4     Parameter ID
	// 12-15   4     String length
	// 16+     var   String data (padded to 4-byte boundary)

	paramStart := len(buf)

	// Type
	buf = append(buf, 0x00, 0x00, 0x00, 0x04) // MQCFT_STRING

	// Length placeholder
	lenPos := len(buf)
	buf = append(buf, 0x00, 0x00, 0x00, 0x00)

	// Parameter ID
	buf = append(buf, 0x00, 0x00, 0x07, 0xE0) // 2016 = MQCA_Q_NAME

	// String length
	buf = append(buf, byte((len(queueName)>>24)&0xFF), byte((len(queueName)>>16)&0xFF),
		byte((len(queueName)>>8)&0xFF), byte(len(queueName)&0xFF))

	// String data
	buf = append(buf, []byte(queueName)...)

	// Padding to 4-byte boundary
	padding := (4 - (len(queueName) % 4)) % 4
	for i := 0; i < padding; i++ {
		buf = append(buf, 0x00)
	}

	// Update parameter length
	paramLen := len(buf) - paramStart
	binary.BigEndian.PutUint32(buf[lenPos:], uint32(paramLen))

	// Update parameter count if needed
	binary.BigEndian.PutUint32(buf[paramCountPos:], 1)

	h.logger.WithFields(map[string]interface{}{
		"queue_name": queueName,
		"msg_size":   len(buf),
	}).Debug("Built INQUIRE_QUEUE_STATUS PCF command")

	return buf
}

// ParseQueueStatusResponse parses a PCF response containing handle details
// Returns a list of queue handles with detailed information
func (h *InquiryHandler) ParseQueueStatusResponse(data []byte) []*QueueHandleDetails {
	handles := make([]*QueueHandleDetails, 0)

	if len(data) < 20 {
		return handles
	}

	// Validate PCF header
	if string(data[0:3]) != "PCF" {
		h.logger.WithField("magic", string(data[0:3])).Debug("Invalid PCF magic")
		return handles
	}

	msgType := binary.BigEndian.Uint32(data[4:8])
	if msgType != 2 { // MQCFT_RESPONSE
		h.logger.WithField("msg_type", msgType).Debug("Not a PCF response")
		return handles
	}

	paramCount := binary.BigEndian.Uint32(data[16:20])
	h.logger.WithField("param_count", paramCount).Debug("Parsing PCF response parameters")

	// Parse parameters
	offset := 20
	currentHandle := &QueueHandleDetails{}
	handleCount := 0

	for offset < len(data) {
		if offset+8 > len(data) {
			break
		}

		paramType := binary.BigEndian.Uint32(data[offset : offset+4])
		paramLen := binary.BigEndian.Uint32(data[offset+4 : offset+8])

		if offset+8+int(paramLen) > len(data) {
			break
		}

		paramData := data[offset+8 : offset+8+int(paramLen)]
		offset += 8 + int(paramLen)

		// Handle parameter based on type
		switch paramType {
		case 20: // MQCFT_GROUP - Start of a new handle group
			if handleCount > 0 && currentHandle.QueueName != "" {
				handles = append(handles, currentHandle)
			}
			currentHandle = &QueueHandleDetails{}
			handleCount++

		case 4: // MQCFT_STRING
			h.parseStringParameter(paramData, currentHandle)

		case 3: // MQCFT_INTEGER
			h.parseIntegerParameter(paramData, currentHandle)
		}
	}

	// Add last handle if any
	if handleCount > 0 && currentHandle.QueueName != "" {
		handles = append(handles, currentHandle)
	}

	h.logger.WithField("handles_found", len(handles)).Debug("Parsed queue handles from PCF response")
	return handles
}

func (h *InquiryHandler) parseStringParameter(paramData []byte, handle *QueueHandleDetails) {
	if len(paramData) < 8 {
		return
	}

	paramID := binary.BigEndian.Uint32(paramData[0:4])
	strLen := binary.BigEndian.Uint32(paramData[4:8])

	if 8+int(strLen) > len(paramData) {
		return
	}

	strValue := strings.TrimRight(string(paramData[8:8+strLen]), "\x00 ")

	switch paramID {
	case 2016: // MQCA_Q_NAME
		handle.QueueName = strValue
	case 3501: // MQCA_CHANNEL_NAME (or MQCACF_CHANNEL_NAME)
		handle.ChannelName = strValue
	case 3502: // MQCA_CONNECTION_NAME (or MQCACF_CONNECTION_NAME)
		handle.ConnectionName = strValue
	case 2024: // MQCA_APPL_NAME
		// This is application name
	case 2549: // MQCACF_APPL_TAG
		handle.ApplicationTag = strValue
	case 3000: // MQCA_USER_IDENTIFIER or similar
		handle.UserID = strValue
	}
}

func (h *InquiryHandler) parseIntegerParameter(paramData []byte, handle *QueueHandleDetails) {
	if len(paramData) < 12 {
		return
	}

	paramID := binary.BigEndian.Uint32(paramData[0:4])
	intValue := int32(binary.BigEndian.Uint32(paramData[8:12]))

	switch paramID {
	case 3002: // MQIACF_PROCESS_ID
		handle.ProcessID = intValue
	}
}
