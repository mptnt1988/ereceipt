# ereceipt
## Quick Start
#### Build
At the project root directory:
```sh
$ make [build]
```
After this command, executable *./ereceipt* will be generated.
To install this to home directory, you can use:
```sh
$ mix escript.install
```
Add *~/.mix/escripts/ereceipt* to PATH so that you can run this everywhere using local configuration files.
#### Run test cases
At the project root directory:
```sh
$ make test
```
#### Run example
At the project root directory:
```sh
$ make example
```
This command will running application with data files in *test/example* directory
## Documentation
To get help:
```sh
$ ereceipt -h
```
With *categories.csv*, *tax.conf* and *input.csv* existed in local directory:
```sh
$ ereceipt
```
To manually sepecify those files:
```sh
$ ereceipt -i input.csv -i input2.csv -i input3.csv -t tax.conf -c categories.csv
```
To also write result into output CSV (in current directory) instead of stdout only:
```sh
$ ereceipt -o ""
```
... or specified output directory:
```sh
$ ereceipt -o "test/example"
```
Output files named *output_\*.csv* will be created.
