#! /bin/bash
# Usage:
#   dotatodocbook.sh [DITAMAP]

## This tool
mydir="$(dirname $0)"

## Input
inputmap="$1"
basedir="$(dirname $inputmap)"
# FIXME: The image directory is totally hard-coded, so does not work
# correctly on non-Fujitsu-CMM stuff
baseimagedir="$basedir/images"
inputbasename="$(basename $1 | sed -r 's/.ditamap$//')"

## Output
outputdir="$basedir/converted/$inputbasename"
outputxmldir="$outputdir/xml"
outputpngdir="$outputdir/images/src/png"

## Find the source files in the ditamap
sourcefiles="$(sed -r -e 's!-->!⁜!g' -e 's/<!--[^⁜]*⁜//g' $1 | grep -oP 'href=\"[^\"]+\"' | sed -r -e 's/^href=\"//' -e 's/\"$//' | tr '\r' ' ')"

## Modify the original DITA files to get rid of duplicate IDs.

# Guiding principle: Don't touch those with XML tools, for fear the DITA
# source might explode in our hands... Not sure that is a rational guiding
# principle. Would need checking.

allids="$(xsltproc $mydir/find-ids.xsl $sourcefiles | sort)"
uniqueids=$(echo -e "$allids" | uniq)
nonuniqueids=$(comm -2 -3 <(echo -e "$allids") <(echo -e "$uniqueids") 2> /dev/null | uniq | tr '\n' '|' | sed 's/|$//')

tmpdir=$(mktemp -d -p '/tmp' -t 'db-convert-XXXXXXX')

for sourcefile in $sourcefiles; do
  mkdir -p "$tmpdir/$(dirname $sourcefile)"
  cp "$sourcefile" "$tmpdir/$(dirname $sourcefile)"
  hasnuids=$(grep -noP " id=\"($nonuniqueids)\"" "$tmpdir/$sourcefile")
  countnuids=$(echo "$hasnuids" | wc -l)
  if [[ ! "$hasnuids" ]]; then
   countnuids=0
  fi
  if [[ "$countnuids" -gt 0 ]]; then
    for line in $(echo -e "$hasnuids" | sed -r 's/^([0-9]+).*/\1/'); do
      # FIXME: Will do dumb things if there are multiple IDs on a line but
      # just one is supposed to be replaced. Fingers crossed & hope for the best.
      paul="$(( ( RANDOM % 9999999 ) + 1 ))"
      sed -i -r "${line}s/\bid=\"[^\"]+\"/id=\"id${paul}\"/g" "$tmpdir/$sourcefile"
    done
  fi
done

## Create output dirs
mkdir -p "$outputxmldir" 2> /dev/null
mkdir -p "$outputpngdir" 2> /dev/null

## From the ditamap, create a MAIN file.

# FIXME: This does not work.
# saxon9 -xsl:"$mydir/map2docbook.xsl" -s:"$1" -o:"$outputxmldir/MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml"

# Therefore, let's do this the most simplistic & idiotic way possible...
# FIXME: Unfortunately, this also destroys the structure somewhat.
mainfile="$outputxmldir/MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml"
cat <<EOF > $mainfile
<?xml version="1.0" encoding="utf-8"?>
<?xml-stylesheet
href="urn:x-daps:xslt:profiling:docbook45-profile.xsl" type="text/xml"
title="Profiling step" ?>
<!DOCTYPE article PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.docbook.org/xml/4.5/docbookx.dtd"
[
]>
<article lang="en">
 $(grep -oP -m1 '<title>[^<]+</title>' "$1")
EOF

## Actual conversion
for sourcefile in $sourcefiles; do
  actualfile="$(echo $sourcefile | sed -r 's_/_-_g')"
  actualpath="$outputxmldir/$actualfile"
  saxon9 -xsl:"$mydir/dita2docbook_template.xsl" -s:"$tmpdir/$sourcefile" -o:"$actualpath" 2>> "$tmpdir/saxon-log"
  echo "<xi:include href=\"$actualfile\" xmlns:xi=\"http://www.w3.org/2001/XInclude\"/>" >> $mainfile
done

echo "</article>" >> $mainfile

## Create a very basic DC file

dcfile="$outputdir/DC-$inputbasename"
echo "MAIN=$(basename $mainfile)" > "$dcfile"

## Collect linkends, clean up all the IDs that are not used, also clean up
## filerefs in imageobjects and replace ex-conref'd contents with entities.

# FIXME: Do we still want to clean up all the ID names? It should not hurt
linkends=$(grep -oP "linkend=\"[^\"]+\"" $outputxmldir/*.xml | sed -r -e 's/(^[^:]+:linkend=\"|\"$)//g' | uniq | tr '\n' ' ' | sed -e 's/^./ &/g' -e 's/.$/& /g' )
for sourcefile in $sourcefiles; do
  actualfile="$outputxmldir/$(echo $sourcefile | sed -r 's_/_-_g')"
  xsltproc --stringparam "linkends" "$linkends" "$mydir/clean-ids.xsl" "$actualfile" > "$actualfile.0" 2>> "$tmpdir/neededstuff"
  mv $actualfile.0 $actualfile
done

## Create an entity file & copy necessary images

# FIXME: Neither of these are safe for names with spaces in them, because they
# don't iterate over lines, at least not per se :/
entitiesneeded="$(sed -n -r 's/^need-entity:// p' $tmpdir/neededstuff | sort | uniq)"
{
  for entity in $entitiesneeded; do
    # FIXME: Currently, there is just dummy content in the generated entities.
    echo "<!ENTITY $(echo $entity | sed -r 's/^([^,]+).*$/\1/') \"FIXME, I am an entity. Original content at: $(echo $entity | sed -r 's/^[^,]+,(.*)$/\1/')\">"
  done
} > "$outputxmldir/entities.ent"

imagesneeded="$(cat $tmpdir/neededstuff | sed -n 's/need-image:// p' | sort | uniq)"
for image in $imagesneeded; do
  cp "$baseimagedir/$(basename $(echo $image | sed -r 's/^[^,]+,(.*)$/\1/'))" "$outputpngdir/$(echo $image | sed -r 's/^([^,]+).*$/\1/')"
done

echo ""
echo "Temporary directory: $tmpdir"
echo "Output directory:    $outputdir"
