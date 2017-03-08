## DITA to DocBook Conversion for DAPS

Does not work particularly well.

Most content stolen from https://github.com/dita-ot/org.dita.docbook (without going to the trouble of importing Git commits or giving proper credit).

Licensed as Apache 2.0.


### Prerequisites

Packages to install on openSUSE:

* `saxon9`, `saxon9-scripts`
* `dita`


### Usage

1. Pick a `*.ditamap` file and run the script on it:
   `./ditatodocbook.sh [DITAMAP-FILE]`
1. Find the output in the subdirectory "converteddocbook" of the directory
   of your `*.ditamap` file
1. You can now run `daps validate` on the generated content:
