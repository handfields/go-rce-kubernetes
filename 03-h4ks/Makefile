go-fake-crypto:
	# Build static binary 
	CGO_ENABLED=0 GOOS=linux go build -ldflags '-extldflags "-fno-PIC -static"' ./go-fake-crypto.go 
	tar czvf go-fake-crypto.tar.gz go-fake-crypto 
	rm go-fake-crypto
	