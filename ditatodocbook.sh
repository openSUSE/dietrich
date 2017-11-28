#! /bin/bash
# Usage:
#   $0 [-v] [DITAMAP]
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
#     + STYLEROOT: Style root to write into the DC file. (default: [none])
#     + CLEANTEMP: Delete temporary directory after conversion. (default: 1)
#     + CLEANID: Remove IDs that are not used as linkends. (default: 1)
#     + TWEAK: Space-separated list of vendor tweaks to apply.
#         (default: [none], available:
#           "fujitsu" - convert emphases starting with "PENDING:" to <remark/>s,
#              remove emphases from link text
#         )
#     + ENTITYFILE: File name (not path!) of an external file that will be
#         included with all XML files. To reuse an existing file, it has to
#         exist below [OUTPUTDIR]/xml, if it does not, an empty file will be
#         created. (default: "entities.xml")
#     + [DITAMAP]_DC: Name of output DC file.
#         (default: DC-[DITAMAP's_NAME])
#     + [DITAMAP]_MAIN: Name of output main file.
#         (default: MAIN.[DITAMAP's_NAME].xml)
#     + [DITAMAP]_REPLACE: Space-separated list of files that will be replaced
#         by a different DocBook file or removed. Newly included files must
#         either already be placed in [OUTPUTDIR]/xml or be available in the
#         same directory as [DITAMAP].
#         NOTE: Newly included files will be used as-is, without conversion,
#         addition of XIncludes or extra entities. Images referenced in newly
#         included files will not be copied.
#         (default: [none], syntax:
#           "relative/path/old.xml=new.xml relative/path/old2.xml=new2.xml ..."
#         )
#     + [DITAMAP]_REMOVE: Space-separated list of files that will be removed.
#         NOTE: This option also removes files that are included within the
#         reference of the removed file.
#         NOTE: If a file is supposed to be both removed and replaced, it will
#         always be removed.
#         (default: [none], syntax:
#           "relative/path/old.xml relative/path/old2.xml ..."
#         )

#
# Package Dependencies on openSUSE:
#   daps dita saxon9-scripts ImageMagick


## This script
me="$(test -L $(realpath $0) && readlink $(realpath $0) || echo $(realpath $0))"
mydir="$(dirname $me)"

verbose=0
if [[ $1 == '-v' ]]; then
  verbose=1
  shift
fi

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


## Configurable options
OUTPUTDIR="$basedir/converted/$inputbasename"
STYLEROOT=""
CLEANTEMP=1
CLEANID=0
TWEAK=""
ENTITYFILE="entities.xml"

## Source a config file, if any
# This is an evil security issue but let's ignore that for the moment.
if [[ -s "$basedir/conversion.conf" ]]; then
  options="$(sed -rn '/#!/{n; p; :loop n; p; /^[ \t]*$/q; b loop}' $0 | sed -r -n 's/^# +\+ ([^:]+):.*/\1/ p' | tr '\n' '|' | sed -r -e "s/\[DITAMAP\]/$inputbasename/g" -e 's/\|$//')"
  if [[ $verbose == 1 ]]; then
    echo "Available options: $(echo $options | sed -r 's/\|/ /g')"
    echo -n "Options recognized in conversion.conf: "
    sed -rn "s/[ \t]*($options)=.*/\1/ p" "$basedir/conversion.conf" | tr '\n' ' '
    echo -e "\n  (For information, see --help.)"
  fi
  . "$basedir/conversion.conf" || true
else
  echo "Did not find conversion.conf: Using default settings."
fi

## Output (fix)
outputxmldir="$OUTPUTDIR/xml"
outputimagedir="$OUTPUTDIR/images/src"

# Eval depending on the content of a sourced script. I know. Sorry.
dcname="DC-$inputbasename"
mainname="MAIN.$inputbasename.xml"
if [[ $(eval echo "\$${inputbasename}_DC") ]]; then
  dcname=$(eval echo "\$${inputbasename}_DC")
fi
if [[ $(eval echo "\$${inputbasename}_MAIN") ]]; then
  mainname=$(eval echo "\$${inputbasename}_MAIN")
fi

replace=$(eval echo "\$${inputbasename}_REPLACE")
remove=$(eval echo "\$${inputbasename}_REMOVE")

replacements="$(echo $replace | sed -r 's@( |^)[^= ]+=@ @g')"
replacementnotfound=0
for replacement in $replacements; do
  if [[ ! -f "$basedir/$replacement" ]]; then
    echo "(meh) Replacement file does not exist: $basedir/$replacement"
    replacementnotfound=1
  fi
done
if [[ $replacementnotfound == 1 ]]; then
  exit
fi

## Create temporary/output dirs
tmpdir=$(mktemp -d -p '/tmp' -t 'db-convert-XXXXXXX')
mkdir -p "$outputxmldir"

## From the ditamap, create a MAIN file.

mainfile="$outputxmldir/$mainname"
# --novalid is necessary for the Fujitsu stuff since we seem to lack the right DTD
xsltproc --novalid \
  --stringparam "prefix" "$inputbasename" \
  --stringparam "entityfile" "$ENTITYFILE" \
  --stringparam "replace" " $replace " \
  --stringparam "remove" " $remove " \
  "$mydir/map-to-MAIN.xsl" \
  "$inputmap" > "$mainfile" 2> "$tmpdir/includes"

## Find the source files in the ditamap
sourcefiles="$(sed -n -r 's/^source-file:// p' $tmpdir/includes)"
replacedfiles="$(sed -n -r 's/^source-file-replaced:// p' $tmpdir/includes)"

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
allids="$(xmllint --xpath '//@id|//@xml:id' $tempsourcefiles 2> /dev/null | tr ' ' '\n' | sed -r -e 's/^(xml:)?id=\"//' -e 's/\"$//' | sort)"
nonuniqueids=$(echo -e "$allids" | uniq -d | tr '\n' ' ')

for sourcefile in $sourcefiles; do
    xsltproc \
      --stringparam "nonuniqueids" "$nonuniqueids"\
      --stringparam "self" "$sourcefile"\
      --stringparam "prefix" "$inputbasename"\
      "$mydir/create-unique-ids.xsl" \
      "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile-0"
    mv "$tmpdir/$sourcefile-0" "$tmpdir/$sourcefile"
done

## Actual conversion
outputfiles=""
for sourcefile in $sourcefiles; do
  # We need the name of the ditamap in here, because you might want to
  # generate DocBook files for multiple ditamaps into the same directory, if
  # these files then overwrite each other, we might run into issue because
  # they might include wrong XIncludes (which we might not even notice) or
  # wrong root elements (which we are more likely to notice)
  outputfile="${inputbasename}-$(echo $sourcefile | sed -r 's_[/, ]_-_g')"
  outputpath="$outputxmldir/$outputfile"
  saxon9 -xsl:"$mydir/dita2docbook_template.xsl" -s:"$tmpdir/$sourcefile" -o:"$outputpath"

  # Also generate list of output files for later reuse
  outputfiles="$outputfiles $outputpath"
done

## Create a very basic DC file

dcfile="$OUTPUTDIR/$dcname"
{
  echo "MAIN=$mainname"
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
  linkends=" $(xmllint --xpath '//@linkend' $outputfiles 2> /dev/null | tr ' ' '\n' | sed -r -e 's/^linkend=\"//' -e 's/\"$//' | sort | uniq | tr '\n' ' ') "
fi


for outputpath in $outputfiles; do
# FIXME: This currently leads to some text-completeness issues.
  problematicblocks="self::address|self::bibliolist|self::blockquote|self::bridgehead|self::calloutlist|self::caution|self::classsynopsis|self::cmdsynopsis|self::constraintdef|self::constructorsynopsis|self::destructorsynopsis|self::epigraph|self::equation|self::example|self::fieldsynopsis|self::figure|self::funcsynopsis|self::glosslist|self::important|self::informalexample|self::informalfigure|self::informaltable|self::itemizedlist|self::literallayout|self::mediaobject|self::methodsynopsis|self::msgset|self::note|self::orderedlist|self::procedure|self::procedure|self::productionset|self::programlisting|self::programlistingco|self::qandaset|self::revhistory|self::screen|self::screenco|self::screenshot|self::segmentedlist|self::sidebar|self::simplelist|self::synopsis|self::table|self::task|self::tip|self::variablelist|self::warning"

  # Oh my. Is there anything where I don't apply the rinse/repeat strategy?
  # This is getting old fast. FIXME
  while [[ $(xmllint --xpath "//*[(${problematicblocks}) and parent::para]" "$outputpath" 2> /dev/null) ]]; do
    xsltproc \
      "$mydir/clean-blocks.xsl" \
      "$outputpath" > "$outputpath.0"
    mv $outputpath.0 $outputpath
  done

  outputfile="$(basename $outputpath)"
  root=$(grep -m1 "^file:$outputfile,root:" $tmpdir/includes | sed -r 's_^.+,root:(.+)$_\1_')
  includes=$(grep -P "^append-to:$outputfile,generate-include:" $tmpdir/includes | sed -r 's_^.+,generate-include:(.+)$_\1_' | tr '\n' ',')
  xsltproc \
    --stringparam "linkends" "$linkends" \
    --stringparam "root" "$root" \
    --stringparam "includes" "$includes" \
    --stringparam "relativefilepath" "$(dirname $sourcefile)" \
    --stringparam "tweaks" " $TWEAK " \
    --stringparam "entityfile" "$ENTITYFILE" \
    "$mydir/clean-ids.xsl" \
    "$outputpath" > "$outputpath.0" 2>> "$tmpdir/neededstuff"
  mv $outputpath.0 $outputpath
done

## Copy replaced files

for replacedfile in $replacedfiles; do
  cp "$basedir/$replacedfile" "$outputxmldir/$replacedfile"
done

## Create entity file

if [[ ! -f "$outputxmldir/$ENTITYFILE" ]] && [[ -f "$basedir/$ENTITYFILE" ]]; then
  cp "$basedir/$ENTITYFILE" "$outputxmldir/$ENTITYFILE"
else
  touch "$outputxmldir/$ENTITYFILE"
fi

## Copy necessary images

# For images, we do not yet generate file names that include the name of the
# ditamap file. However, since images don't change with profiling/ditamap
# content etc., that should not matter.
imagesneeded="$(cat $tmpdir/neededstuff | sed -n 's/need-image:// p' | sort | uniq)"
for image in $imagesneeded; do
  sourceimage="$(echo $image | sed -r 's/^[^,]+,(.*)$/\1/')"
  outputimage="$(echo $image | sed -r 's/^([^,]+).*$/\1/')"
  imagetype="$(echo $outputimage | grep -ioP '[a-z0-9]+$' | sed -r -e 's/[A-Z]/\L&/g' -e 's/jpeg/jpg/')"
  mkdir -p "$outputimagedir/$imagetype" 2> /dev/null
  if [[ $imagetype == 'png' ]] || [[ $imagetype == 'jpg' ]]; then
    # Throw out everything we don't need for building books because FOP might
    # later choke on non-standard stuff.
    convert "$basedir/$sourceimage" -strip "$outputimagedir/$imagetype/$outputimage"
  else
    cp "$basedir/$sourceimage" "$outputimagedir/$imagetype/$outputimage"
  fi
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
