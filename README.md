# regfinder

Fast simple regex matcher that should be used as simple manual checker for secrets in your file.
Useful for secret detection in your codebase and very easy to extend existing regex patterns. 

This tool might have a high false positive rate, which is dependant on the regexes you use. 
RegFinder is not meant for automated pipeline, however it comes handy in situations where more manual is expected (e.g. Security code review, Pentest...).


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
