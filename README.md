# regfinder

Fast, simple regex matcher that should be used as a simple manual checker for secrets in your project.
It is helpful for secret detection in your codebase and makes it very easy to extend existing regex patterns. 

This tool might have a high false positive rate depending on your regexes. 
RegFinder is not meant for automated pipelines. However, it comes in handy when more manual work is required (e.g., security code review, Pentest, etc.).

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
