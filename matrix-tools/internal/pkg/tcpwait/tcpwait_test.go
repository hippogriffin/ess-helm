package tcpwait

import (
	"net"
	"testing"
)

// TestTCPWait tests that the tcpwait function correctly waits for a TCP connection.
func TestTCPWait(t *testing.T) {
	// Start a local TCP server in a goroutine
	listener, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Failed to start listener: %v", err)
	}
	defer listener.Close()

	// Get the address of the local TCP server
	serverAddr := listener.Addr().String()

	// Start a goroutine to handle incoming connections and close them immediately
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			t.Errorf("Accept error: %v", err)
			return
		}
		defer conn.Close()
	}()

	// Call the tcpwait function with the server address and timeout
	WaitForTCP(serverAddr)
}
