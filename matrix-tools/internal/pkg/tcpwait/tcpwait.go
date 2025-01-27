// internal/tcpwait/wait.go

package tcpwait

import (
	"fmt"
	"net"
	"time"
)

// WaitForTCP waits for a TCP connection on the specified address.
func WaitForTCP(server string, port string) {
	address := server + ":" + port
	for {
		fmt.Println("Waiting for TCP connection on " + address)
		conn, err := net.DialTimeout("tcp", address, 5*time.Second)
		defer conn.Close()
		if err == nil {
			break
		}
		time.Sleep(time.Second)
	}
}
