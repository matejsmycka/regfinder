BINARY-NAME=regfinder
WIN-BUILD= GOARCH=amd64 GOOS=windows
LINUX-BUILD= GOARCH=amd64 GOOS=linux
FILE=main.go
OUTPUT-DIR=build


build:
	go mod download
	mkdir -p $(OUTPUT-DIR)
	$(WIN-BUILD) go build -o $(OUTPUT-DIR)/$(BINARY-NAME).exe $(FILE)
	$(LINUX-BUILD) go build -o $(OUTPUT-DIR)/$(BINARY-NAME).elf $(FILE)

clean:
	rm -rf $(OUTPUT-DIR)

run:
	go run $(FILE) $(ARGS)