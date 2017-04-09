#! /bin/bash
# Usage:
#   ditatodocbook.sh [DITAMAP]
#
# Configuration:
#   * Add a file called conversion.conf to the directory of your DITAMAP
#   * The configuration file will be sourced by the script
#   * Recognized options:
#     + outputdir: The directory to place output in. Can but does not have to
#         exist. Existing files will be overwritten mercilessly.
#         (default: [DITAMAP's_DIR]/converted/[DITAMAP's_NAME])
#     + styleroot: Style root to write into the DC file. (default: none)
#     + cleanup: Delete temporary directory after conversion. (default: 1)

if [[ $1 == '--help' ]] || [[ $1 == '-h' ]] || [[ ! $1 ]]; then
  sed -rn '/#!/{n; p; :loop n; p; /^[ \t]*$/q; b loop}' $0 | sed -r 's/^# ?//'
  exit
fi

## This tool
mydir="$(realpath $(dirname $0))"

## Input
inputmap="$1"
basedir="$(realpath $(dirname $inputmap))"
# FIXME: The image directory is totally hard-coded, so does not work
# correctly on non-Fujitsu-CMM stuff
inputbasename="$(basename $1 | sed -r 's/.ditamap$//')"

## Configurable options
outputdir="$basedir/converted/$inputbasename"
styleroot=""
cleanup=1

## Source a config file, if any
# This is an evil security issue but let's ignore that for the moment.
test -s "$basedir/conversion.conf" && . "$basedir/conversion.conf" || true

## Output (fix)
outputxmldir="$outputdir/xml"
outputimagedir="$outputdir/images/src"

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

allids="$(xsltproc $mydir/find-ids.xsl $sourcefiles | sort)"
uniqueids=$(echo -e "$allids" | uniq)
nonuniqueids=$(comm -2 -3 <(echo -e "$allids") <(echo -e "$uniqueids") 2> /dev/null | uniq | tr '\n' '|' | sed 's/|$//')

for sourcefile in $sourcefiles; do
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


## Actual conversion
for sourcefile in $sourcefiles; do
  outputfile="$(echo $sourcefile | sed -r 's_[/, ]_-_g')"
  outputpath="$outputxmldir/$outputfile"
  saxon9 -xsl:"$mydir/dita2docbook_template.xsl" -s:"$tmpdir/$sourcefile" -o:"$outputpath"
done

## Create a very basic DC file

dcfile="$outputdir/DC-$inputbasename"
{
  echo "MAIN=$(basename $mainfile)"
  if [[ $styleroot != '' ]]; then
    echo "STYLEROOT=$styleroot"
  fi
} > "$dcfile"

## Collect linkends, clean up all the IDs that are not used, also clean up
## filerefs in imageobjects and replace ex-conref'd contents with entities.

# FIXME: Do we still want to clean up all the ID names? It should not hurt
linkends=$(grep -oP "\blinkend=\"[^\"]+\"" $outputxmldir/*.xml | sed -r -e 's/(^[^:]+:linkend=\"|\"$)//g' | uniq | tr '\n' ' ' | sed -e 's/^./ &/g' -e 's/.$/& /g' )
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
if [[ $cleanup = 1 ]]; then
  rm -r $tmpdir
else
  echo "Temporary directory: $tmpdir"
fi
echo "Output directory:    $outputdir"
