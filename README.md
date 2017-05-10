## DITA to DocBook Conversion for DAPS

Occasionally even works as intended. Originally written to import Fujitsu CMM documentation. 

The core DITA/DocBook transformation stylesheets come from
https://github.com/dita-ot/org.dita.docbook

Licensed as Apache 2.0.


### Prerequisites

Packages to install on openSUSE:

* `daps`
* `dita`
* `saxon9-scripts`
* `imagemagick`


### Usage

Pick a `*.ditamap` file and run the script on it:
`./dtdbcd [DITAMAP-FILE]`

The output path will be printed at the end, by default, it is the subdirectory
`converted/[NAME-OF-DITAMAP]` of the directory of your `*.ditamap` file.

For more information, run `./dtdbcd --help`.


### Configuration

You can add a file called `conversion.conf` to the directory of your
`*.ditamap` file. Supported options are explained with `./dtdbcd --help`.

`conversion.conf` can contain any valid Bash syntax -- it will be sourced by
the main Bash script.

### Installation

There is no need to install `dtdbcd`. As long as the dependencies are installed,
it will JustRun(TM).

However, it might make your life easier to add a symbolic link for `dtdbcd`
to a directory in your `$PATH`. To do so, run either of the following from
the checkout directory:

* Local: `ln -s ditatodocbook.sh ~/bin/dtdbcd`
* Global: `sudo ln -s ditatodocbook.sh /usr/bin/dtdbcd`
