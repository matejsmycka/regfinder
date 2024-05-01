# regfinder

Fast, simple regex matcher that should be used as a simple manual checker for secrets in your project.
It is helpful for secret detection in your codebase and makes it very easy to extend existing regex patterns. 

This tool might have a high false positive rate depending on your regexes. 
RegFinder comes handy in situations where more manual work is required (e.g., security code review, Pentest, etc.).

The functionality of this tool is more or less the same as GNU grep, in the `grep` you can achieve the functionality with the following command: `grep -n -r your_app/ -Ef regex_dir/general.txt` 
The advantages of this tool is that it is multithreaded and faster on larger projects, then it automatically ignores some files that typically have no secrets such as pdfs, images, etc.
At the same time it is very easily expandable for your purposes, it is statically linked (like everything in golang) and portable. There are executables for both linux and windows.

## Setup 

Copy the executable from the `/build` folder to `/usr/local/bin`.

```bash
wget https://github.com/matejsmycka/regfinder/raw/main/build/regfinder.elf
chmod +x ./regfinder.elf
sudo mv ./regfinder.elf /usr/local/bin/regfinder
```

## Usage

```bash
Usage of regfinder:
  -d string
    	Directory to search for files (recursively)
  -f string
    	File containing regular expressions to search for
  -no-color
    	Disable color output
```

To build the binary, run `make` in the root directory of the project, output dir is `built`.

## Example

```bash
$ ./regfinder.elf -d your_app/ -f regex_dir/general.txt

```

## Regex directory

Regex for each use-case are included in `regex_dir` directory. You can use them as a base for your own regexes.

## Dev

```bash
make run ARGS="-d your_app/ -f regex_dir/general.txt"
```
