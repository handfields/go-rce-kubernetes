package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"time"
)

// Fake crypto example
// Please refer to the README for more information.
func main() {
	switch {
	case len(os.Args) > 1:
		url := os.Args[1]
		conn, err := net.Dial("tcp", url)
		if err != nil {
			fmt.Println("FAILED: check your wallet!")
		} else {
			defer conn.Close()
			for i := 0; i < 50; i++ {
				time.Sleep(2 * time.Second)
				sendMoney(conn)
			}
		}
	default:
		fmt.Println("where do you want to send the money?")
	}
}

func sendMoney(conn net.Conn) {
	b := make([]byte, 32)
	rand.Read(b)
	c := hex.EncodeToString(b)

	fmt.Fprintf(conn, "money: "+c+"\r\n")
}
