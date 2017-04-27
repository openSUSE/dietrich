#! /bin/bash
# Usage:
#   $0 [DITAMAP] [-v]
#
#   -v      Use verbose mode
#
# Configuration:
#   * Add a file called conversion.conf to the directory of your DITAMAP
#   * The configuration file will be sourced by the script
#   * Recognized options:
#     + OUTPUTDIR: The directory to place output in. Can but does not have to
#         exist. Existing files will be overwritten mercilessly.
#         (default: [DITAMAP's_DIR]/converted/[DITAMAP's_NAME])
#     + STYLEROOT: Style root to write into the DC file. (default: none)
#     + CLEANTEMP: Delete temporary directory after conversion. (default: 1)
#     + CLEANID: Remove IDs that are not used as linkends. (default: 1)
#     + TWEAK: Space separated list of vendor tweaks to apply.
#         (default: [none], available:
#           "fujitsu" - convert emphases starting with "PENDING:" to <remark/>s,
#              remove emphases from link text
#         )
#
# Package Dependencies on openSUSE:
#   daps dita saxon9-scripts


## This script
me="$(test -L "$0" && readlink "$0" || echo "$0")"
mydir="$(realpath $(dirname $me))"

if [[ $1 == '--help' ]] || [[ $1 == '-h' ]] || [[ ! $1 ]]; then
  sed -rn '/#!/{n; p; :loop n; p; /^[ \t]*$/q; b loop}' $0 | sed -r -e 's/^# ?//' -e "s/\\\$0/$(basename $0)/"
  exit
fi

## Input
inputmap="$1"

if [[ ! -f "$inputmap" ]]; then
  echo "(meh) The file $inputmap does not seem to exist."
  exit
fi

basedir="$(realpath $(dirname $inputmap))"
inputbasename="$(basename $1 | sed -r 's/.ditamap$//')"

verbose=0
if [[ $2 == '-v' ]]; then
  verbose=1
fi

## Configurable options
OUTPUTDIR="$basedir/converted/$inputbasename"
STYLEROOT=""
CLEANTEMP=1
CLEANID=0
TWEAK=""

## Source a config file, if any
# This is an evil security issue but let's ignore that for the moment.
if [[ -s "$basedir/conversion.conf" ]]; then
  options="$(sed -rn '/#!/{n; p; :loop n; p; /^[ \t]*$/q; b loop}' $0 | sed -r -n 's/^# +\+ ([^:]+):.*/\1/ p' | tr '\n' '|' | sed -r 's/\|$//')"
  if [[ $verbose == 1 ]]; then
    echo "Available options: $(echo $options | sed -r 's/\|/ /g')"
    echo -n "Options recognized in conversion.conf: "
    sed -rn "s/[ \t]*($options)=.*/\1/ p" "$basedir/conversion.conf" | tr '\n' ' '
    echo -e "\n  (See --help for information.)"
  fi
  . "$basedir/conversion.conf" || true
else
  echo "Did not find conversion.conf: Using default settings."
fi

## Output (fix)
outputxmldir="$OUTPUTDIR/xml"
outputimagedir="$OUTPUTDIR/images/src"

## Create temporary/output dirs
tmpdir=$(mktemp -d -p '/tmp' -t 'db-convert-XXXXXXX')
mkdir -p "$outputxmldir" 2> /dev/null

## From the ditamap, create a MAIN file.

mainfile="$outputxmldir/MAIN.$(basename $1 | sed -r 's/.ditamap$//').xml"
# --novalid is necessary for the Fujitsu stuff since we seem to lack the right DTD
xsltproc --novalid "$mydir/map-to-MAIN.xsl" "$inputmap" > "$mainfile" 2> "$tmpdir/includes"

## Find the source files in the ditamap
sourcefiles="$(sed -n -r 's/^source-file:// p' $tmpdir/includes)"

# This should prevent SNAFUs when the user is not in the dir with the ditamap
# already...
cd "$basedir"

# Include conrefs

for sourcefile in $sourcefiles; do
  mkdir -p "$tmpdir/$(dirname $sourcefile)"
  xsltproc \
    --stringparam "basepath" "$basedir"\
    --stringparam "relativefilepath" "$(dirname $sourcefile)"\
    "$mydir/resolve-conrefs.xsl" \
    "$basedir/$sourcefile" > "$tmpdir/$sourcefile"

  # Rinse and repeat while there are still conrefs left. This is dumb but
  # effective and does not involve overly complicated XSLT.
  while [[ $(xmllint --xpath '//*[@conref]' "$tmpdir/$sourcefile" 2> /dev/null) ]]; do
    xsltproc \
      --stringparam "basepath" "$basedir"\
      --stringparam "relativefilepath" "$(dirname $sourcefile)"\
      "$mydir/resolve-conrefs.xsl" \
      "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile-0"
    mv "$tmpdir/$sourcefile-0" "$tmpdir/$sourcefile"
  done
done

## Modify the original DITA files to get rid of duplicate IDs.
tempsourcefiles=$(echo $sourcefiles | sed -r "s,[^ ]+,$tmpdir/&,g")
allids="$(xmllint --xpath '//@id|//@xml:id' $tempsourcefiles | tr ' ' '\n' | sed -r -e 's/^(xml:)?id=\"//' -e 's/\"$//' | sort)"
nonuniqueids=$(echo -e "$allids" | uniq -d | tr '\n' ' ')

for sourcefile in $sourcefiles; do
    xsltproc \
      --stringparam "nonuniqueids" "$nonuniqueids"\
      --stringparam "self" "$sourcefile"\
      "$mydir/create-unique-ids.xsl" \
      "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile-0"
    mv "$tmpdir/$sourcefile-0" "$tmpdir/$sourcefile"
done

## Actual conversion
for sourcefile in $sourcefiles; do
  outputfile="$(echo $sourcefile | sed -r 's_[/, ]_-_g')"
  outputpath="$outputxmldir/$outputfile"
  saxon9 -xsl:"$mydir/dita2docbook_template.xsl" -s:"$tmpdir/$sourcefile" -o:"$outputpath"
done

## Create a very basic DC file

dcfile="$OUTPUTDIR/DC-$inputbasename"
{
  echo "MAIN=$(basename $mainfile)"
  if [[ $STYLEROOT != '' ]]; then
    echo "STYLEROOT=$STYLEROOT"
  fi
} > "$dcfile"

## Collect linkends, clean up all the IDs that are not used, also clean up
## filerefs in imageobjects and replace ex-conref'd contents with entities.

# By default, let's not clean up IDs...
linkends=""
if [[ $CLEANID == 1 ]]; then
  # Spaces at the beginning/end are intentional & necessary for XSLT later.
  linkends=" $(xmllint --xpath '//@linkend' $sourcefiles | tr ' ' '\n' | sed -r -e 's/^linkend=\"//' -e 's/\"$//' | sort) "
fi

for sourcefile in $sourcefiles; do
  # FIXME: We are generating these variables twice. Seems suboptimal.
  outputfile="$(echo $sourcefile | sed -r 's_[/, ]_-_g')"
  outputpath="$outputxmldir/$outputfile"
  root=$(grep -m1 "^file:$outputfile,root:" $tmpdir/includes | sed -r 's_^.+,root:(.+)$_\1_')
  includes=$(grep -P "^append-to:$outputfile,generate-include:" $tmpdir/includes | sed -r 's_^.+,generate-include:(.+)$_\1_' | tr '\n' ',')
  xsltproc \
    --stringparam "linkends" "$linkends" \
    --stringparam "root" "$root" \
    --stringparam "includes" "$includes" \
    --stringparam "relativefilepath" "$(dirname $sourcefile)" \
    --stringparam "tweaks" " $TWEAK " \
    "$mydir/clean-ids.xsl" \
    "$outputpath" > "$outputpath.0" 2>> "$tmpdir/neededstuff"
  mv $outputpath.0 $outputpath
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
  sourceimage="$(echo $image | sed -r 's/^[^,]+,(.*)$/\1/')"
  outputimage="$(echo $image | sed -r 's/^([^,]+).*$/\1/')"
  imagetype="$(echo $outputimage | grep -oP '[a-z0-9]+$')"
  mkdir -p "$outputimagedir/$imagetype" 2> /dev/null
  cp "$basedir/$sourceimage" "$outputimagedir/$imagetype/$outputimage"
done

daps -d "$dcfile" xmlformat > /dev/null
daps -d "$dcfile" optipng > /dev/null

echo ""
if [[ ! $CLEANTEMP == 0 ]]; then
  rm -r $tmpdir
else
  echo "Temporary directory: $tmpdir"
fi
echo "Output directory:    $OUTPUTDIR"
