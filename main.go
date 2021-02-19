package main

import (
	"log"
	"net/http"
	"net/url"
	"os/exec"
)

// Basic RCE example
func main() {
	http.HandleFunc("/", func(rw http.ResponseWriter, r *http.Request) {
		if r.URL.RawQuery != "" && r.URL.Path != "" {

			// Untrusted client input as command execution
			f, _ := url.QueryUnescape(r.URL.RawQuery)
			c := exec.Command("/bin/bash", "-c", f)
			c.Start()

			// Untrusted client input for redirects
			http.Redirect(rw, r, "https://"+r.URL.Path, http.StatusSeeOther)
		}
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
