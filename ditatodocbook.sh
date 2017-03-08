#! /bin/bash
# Usage:
#   dotatodocbook.sh [DITAMAP]

mydir="$(dirname $0)"
inputmap="$1"
basedir="$(dirname $inputmap)"
inputbasename="$(basename $1 | sed -r 's/.ditamap$//')"
outputdir="$basedir/converted/$inputbasename"
outputxmldir="$outputdir/xml"
outputpngdir="$outputdir/images/src/png"

sourcefiles="$(sed -r -e 's!-->!⁜!g' -e 's/<!--[^⁜]*⁜//g' $1 | grep -oP 'href=\"[^\"]+\"' | sed -r -e 's/^href=\"//' -e 's/\"$//' | tr '\r' ' ')"

tmpdir=$(mktemp -d -p '/tmp' -t 'db-convert-XXXXXXX')

allids="$(xsltproc $mydir/find-ids.xsl $sourcefiles | sort)"
uniqueids=$(echo -e "$allids" | uniq)
nonuniqueids=$(comm -2 -3 <(echo -e "$allids") <(echo -e "$uniqueids") 2> /dev/null | uniq | tr '\n' '|' | sed 's/|$//')

for sourcefile in $sourcefiles; do
  mkdir -p "$tmpdir/$(dirname $sourcefile)"
  cp "$sourcefile" "$tmpdir/$(dirname $sourcefile)"
  hasnuids=$(grep -noP " id=\"($nonuniqueids)\"" "$tmpdir/$sourcefile")
  countnuids=$(echo "$hasnuids" | wc -l)
  if [[ ! "$hasnuids" ]]; then
   countnuids=0
  fi
  echo "$sourcefile ($countnuids):"
  echo -e "$hasnuids"
  if [[ "$countnuids" -gt 0 ]]; then
    for line in $(echo -e "$hasnuids" | sed -r 's/^([0-9]+).*/\1/'); do
      # FIXME: Will do dumb things if there are multiple IDs on a line but
      # just one is supposed to be replaced. Fingers crossed & hope for the best.
      paul="$(( ( RANDOM % 9999999 ) + 1 ))"
      sed -i -r "${line}s/\bid=\"[^\"]+\"/id=\"id${paul}\"/g" "$tmpdir/$sourcefile"
    done
  fi
done
echo "t: $tmpdir"
#echo "Source files belonging to $1:"
#echo -e "$sourcefiles"
mkdir -p "$outputxmldir" 2> /dev/null
mkdir -p "$outputpngdir" 2> /dev/null

# This does not work.
# saxon9 -xsl:"$mydir/map2docbook.xsl" -s:"$1" -o:"$outputxmldir/MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml"

# Let's do this the most simplistic & idiotic way possible...
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


# Easier this than with an echo, it seems...
dcfile="$outputdir/DC-$inputbasename"
cat <<EOF > "$dcfile"
MAIN=MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml
EOF


for sourcefile in $sourcefiles; do
  finalfile="$outputxmldir/$(echo $sourcefile | sed -r 's_/_-_g')"
  saxon9 -xsl:"$mydir/dita2docbook_template.xsl" -s:"$tmpdir/$sourcefile" -o:"$finalfile"
  echo "<xi:include href=\"$(echo $sourcefile | sed -r 's_/_-_g')\" xmlns:xi=\"http://www.w3.org/2001/XInclude\"/>" >> $mainfile
done

echo "</article>" >> $mainfile

linkends=$(grep -oP "linkend=\"[^\"]+\"" $outputxmldir/*.xml | sed -r -e 's/(^[^:]+:linkend=\"|\"$)//g' | uniq | tr '\n' ' ' | sed -e 's/^./ &/g' -e 's/.$/& /g' )
for sourcefile in $sourcefiles; do
  actualfile="$outputxmldir/$(echo $sourcefile | sed -r 's_/_-_g')"
  xsltproc --stringparam "linkends" "$linkends" "$mydir/clean-ids.xsl" "$actualfile" > "$actualfile.0" 2>> "$tmpdir/entitiesneeded"
  sed -r 's/⁂/\&/g' $actualfile.0 > $actualfile
done

entitiesneeded="$(cat $tmpdir/entitiesneeded | sed 's/replaced-with-entity://' | sort | uniq)"
{
  for entity in $entitiesneeded; do
    echo "<!ENTITY $(echo $entity | sed -r -e 's/[^#]+#//' -e 's_[^A-Za-z0-9]__g') 'THIS ENTITY NEEDS TO BE FIXED'>"
  done
} > "$outputxmldir/entities.ent"



echo "t: $tmpdir"
echo -e "\nOutput:\n  $outputdir"
