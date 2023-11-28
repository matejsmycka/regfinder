# regfinder

Fast, simple regex matcher that should be used as a simple manual checker for secrets in your project.
It is useful for secret detection in your codebase and makes it very easy to extend existing regex patterns. 

Depending on the regexes you use, this tool might have a high false positive rate. 
RegFinder is not meant for automated pipelines. However, it comes in handy in situations where more manual is expected (e.g. Security code review, Pentest...).


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
