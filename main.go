package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/fatih/color"
)

var NO_COLOR = flag.Bool("no-color", false, "Disable color output")

func searchFilesWithRegex(directory, regexFile string) error {
	// Read the list of regular expressions from the regex file.
	regexList, err := readRegexFile(regexFile)
	if err != nil {
		return err
	}

	// Walk through the directory and search files using the regexes.
	err = filepath.Walk(directory, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			if err := searchFileWithRegexes(path, regexList); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	return nil
}

func readRegexFile(filename string) ([]string, error) {
	var regexList []string
	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if line != "" {
			regexList = append(regexList, line)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return regexList, nil
}

func searchFileWithRegexes(filePath string, regexList []string) error {
	fileContent, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}
	fExtension := filePath[len(filePath)-3:]
	if fExtension == "exe" {
		return nil
	}

	lines := strings.Split(string(fileContent), "\n")

	for lineNum, line := range lines {
		for _, regexPattern := range regexList {
			regex, err := regexp.Compile(regexPattern)
			if err != nil {
				return err
			}

			matches := regex.FindAllStringIndex(line, -1)
			if len(matches) > 0 {
				if !*NO_COLOR {
					fmt.Printf("File: %s, Line %d, Match: ", filePath, lineNum+1)
					color.Red("%.100s", line)
				} else {
					fmt.Printf("File: %s, Line %d, Match: %.100s\n", filePath, lineNum+1, line)
				}
			}
		}
	}

	return nil
}

func main() {
	var directory string
	var regexFile string
	flag.StringVar(&directory, "d", "", "Directory to search for files (recursively)")
	flag.StringVar(&regexFile, "f", "", "File containing regular expressions to search for")
	flag.Parse()

	if directory == "" || regexFile == "" {
		fmt.Println("Usage: ./program -d <directory> -f <regex_file>")
		os.Exit(1)
	}

	err := searchFilesWithRegex(directory, regexFile)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
	}
}
