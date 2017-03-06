#! /bin/bash
# Usage:
#   dotatodocbook.sh [DITAMAP]

mydir="$(dirname $0)"
inputmap="$1"
basedir="$(dirname $inputmap)"
outputdir="$basedir/converteddocbook"
outputxmldir="$outputdir/xml"

sourcefiles="$(grep -oP 'href=\"[^\"]+\"' $1 | sed -r -e 's/^href=\"//' -e 's/\"$//')"

#echo "Source files belonging to $1:"
#echo -e "$sourcefiles"
mkdir -p "$outputxmldir" 2> /dev/null

# This does not work.
# saxon9 -xsl:"$mydir/map2docbook.xsl" -s:"$1" -o:"$outputxmldir/MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml"

# Let's do this the most simplistic & idiotic way possible...
mainfile="$outputxmldir/MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml"
cat <<EOF > $mainfile
<?xml version="1.0" encoding="utf-8"?>
<?xml-stylesheet
href="urn:x-daps:xslt:profiling:docbook45-profile.xsl" type="text/xml"
title="Profiling step" ?>
<!DOCTYPE set PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.docbook.org/xml/4.5/docbookx.dtd"
[
]>
<book lang="en">
 $(grep -oP -m1 '<title>[^<]+</title>' "$1")
EOF


# Easier this than with an echo, it seems...
cat <<EOF > "$outputdir/DC-$(basename $1 | sed -r 's/.ditamap$//')"
MAIN=MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml
EOF

cd "$basedir"

for sourcefile in $sourcefiles; do
  saxon9 -xsl:"$mydir/dita2docbook_template.xsl" -s:"$sourcefile" -o:"$outputxmldir/$(echo $sourcefile | sed -r 's_/_-_g')"
  echo "<xi:include href=\"$(echo $sourcefile | sed -r 's_/_-_g')\" xmlns:xi=\"http://www.w3.org/2001/XInclude\"/>" >> $mainfile
done

echo "</book>" >> $mainfile
