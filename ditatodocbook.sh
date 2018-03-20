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
#     + TEMPDIR: Set a fixed directory for temporary files.
#         (default: random directory under /tmp/)
#     + CLEANID: Remove IDs that are not used as linkends. (default: 1)
#     + WELLFORMSTOP: Stop when any XML file is detected as not being
#       well-formed, so an author can manually fix it before continuing.
#       (default: 0)
#     + TWEAK: Space-separated list of vendor tweaks to apply.
#         (default: [none], available:
#           "fujitsu" - convert emphases starting with "PENDING:" to <remark/>s,
#              remove emphases from link text
#         )
#     + ENTITYFILE: File name (not path!) of an external file that will be
#         included with all XML files. To reuse an existing file, it has to
#         exist below [OUTPUTDIR]/xml, if it does not, an empty file will be
#         created. (default: "entities.ent")
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
#   daps dita ImageMagick


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
OUTPUTDIR="converted/$inputbasename"
STYLEROOT=""
CLEANTEMP=1
TEMPDIR=""
WELLFORMSTOP=0
CLEANID=0
TWEAK=""
ENTITYFILE="entities.ent"

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

OUTPUTDIR=$(echo "$OUTPUTDIR" | sed -r -e 's_^file:/+_/_' -e 's_/$__')

outputdirabs="$basedir/$OUTPUTDIR"
if [[ $OUTPUTDIR = /* ]]; then
  outputdirabs="$OUTPUTDIR"
fi

# FUNCTIONS

# "Stop! Wellform Time."
function wellformcheck() {
  # $1 - file to check
  # $2 - who/what is calling this?
  if [[ $WELLFORMSTOP -eq 1 ]]; then
    initialrun=1
    unclean=0
    while [[ $initialrun -eq 1 ]] || [[ $unclean -eq 1 ]]; do
        xmllintrun=$(xmllint --noent --noout "$1" 2> /dev/stdout)
        if [[ $xmllintrun ]]; then
          [[ $verbose -eq 1 ]] && echo "(yno) wellformcheck - $2"
          [[ $initialrun -eq 1 ]] && echo "(meh) $1 is not well-formed (see message above). Fix the file manually."
          echo -e "$xmllintrun"
          read -p "Finished fixing? Press Enter. Ignore issue in file? Press: i, Enter. " decision
          [[ "$decision" == 'i' ]] && break
          unclean=1
        else
          break
        fi
        initialrun=0
    done
  fi
}

# FIXME: This search functions works around the limits of hard-coding. It
# should be here temporarily only.
function searchparents() {
  # $1 - file name to search for
  for parent in "." ".." "../.."; do
    if [[ -f $parent/$1 ]]; then
      echo $basedir/$parent/$1
      break
    fi
  done
  echo ""
}

## Output (fix)
outputxmldir="$outputdirabs/xml"
outputimagedir="$outputdirabs/images/src"

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
if [[ ! $TEMPDIR ]]; then
  tmpdir=$(mktemp -d -p '/tmp' -t 'db-convert-XXXXXXX')
else
  rm -rf "$TEMPDIR/*" 2> /dev/null
  mkdir -p "$TEMPDIR"
  tmpdir="$TEMPDIR"
fi

mkdir -p "$outputxmldir"

echo ""

if [[ $CLEANTEMP == 0 ]]; then
  echo "Temporary directory: $tmpdir"
fi

## From the ditamap, create a MAIN file.

wellformcheck "$inputmap" "before creating MAIN"

mainfile="$outputxmldir/$mainname"
# --novalid is necessary for the Fujitsu stuff since we seem to lack the right DTD
xsltproc --novalid \
  --stringparam "prefix" "$inputbasename" \
  --stringparam "entityfile" "$ENTITYFILE" \
  --stringparam "replace" " $replace " \
  --stringparam "remove" " $remove " \
  "$mydir/map-to-MAIN.xsl" \
  "$inputmap" > "$mainfile" 2> "$tmpdir/includes"

[[ $verbose -eq 1 ]] && echo -e "INCLUDES\n\n$tmpdir/includes\n"

wellformcheck "$mainfile" "after creating MAIN"

## Create entity file

if [[ ! -f "$outputxmldir/$ENTITYFILE" ]] && [[ -f "$basedir/$ENTITYFILE" ]]; then
  cp "$basedir/$ENTITYFILE" "$outputxmldir/$ENTITYFILE"
else
  touch "$outputxmldir/$ENTITYFILE"
fi


## Find the source files in the ditamap
sourcefiles="$(sed -n -r 's/^source-file:// p' $tmpdir/includes)"
replacedfiles="$(sed -n -r 's/^source-file-replaced:// p' $tmpdir/includes)"

# Include conrefs

for sourcefile in $sourcefiles; do
  wellformcheck "$basedir/$sourcefile" "before copying DITA to temporary directory"

  mkdir -p "$tmpdir/$(dirname $sourcefile)"
  cp "$basedir/$sourcefile" "$tmpdir/$sourcefile"

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
  wellformcheck "$tmpdir/$sourcefile" "after resolving conrefs in DITA"
done


# FIXME: hardcoded file names, to allow for converting Helion docs
conkeyrefs_default="HOS-conrefs.xml"
# other conkeyref files (unhandled, TODO):
# install_entryscale_kvm twosystems hw_support_hardwareconfig
keywords_default="HOS-keywords.xml"

# Resolve conkeyref
conkeyrefs=$(searchparents "$conkeyrefs_default")

if [[ -f "$conkeyrefs" ]]; then
  [[ $verbose -eq 1 ]] && echo "Using conkeyref file $CONKEYREFS"

  for sourcefile in $sourcefiles; do
    [[ $verbose -eq 1 ]] && echo "Resolving conkeyrefs for $sourcefile"
    xsltproc \
      --stringparam conrefs.file $conkeyrefs \
      "$mydir/resolve-conkeyref.xsl" \
      "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile-0"
    mv "$tmpdir/$sourcefile-0" "$tmpdir/$sourcefile"
    wellformcheck "$tmpdir/$sourcefile"  "after resolving conkeyrefs in DITA"
  done
fi


## Modify the original DITA files to get rid of duplicate IDs.
tempsourcefiles=$(echo $sourcefiles | sed -r "s,[^ ]+,$tmpdir/&,g")
allids=$(xsltproc --stringparam 'name' 'id' $mydir/find.xsl $tempsourcefiles 2> /dev/null | sort)
nonuniqueids=$(echo -e "$allids" | uniq -d | tr '\n' ' ')

for sourcefile in $sourcefiles; do
    xsltproc \
      --stringparam "nonuniqueids" "$nonuniqueids"\
      --stringparam "self" "$sourcefile"\
      --stringparam "prefix" "$inputbasename"\
      "$mydir/create-unique-ids.xsl" \
      "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile-0"
    mv "$tmpdir/$sourcefile-0" "$tmpdir/$sourcefile"
  wellformcheck "$tmpdir/$sourcefile" "after creating unique IDs in DITA"
done

## Actual conversion
outputfiles=""
for sourcefile in $sourcefiles; do
  # We need the name of the ditamap in here, because you might want to
  # generate DocBook files for multiple ditamaps into the same directory, if
  # these files then overwrite each other, we might run into issue because
  # they might include wrong XIncludes (which we might not even notice) or
  # wrong root elements (which we are more likely to notice)
  outputfile="${inputbasename}-$(echo $sourcefile | sed -r -e 's_[/, ]_-_g' -e 's/\.dita$/.xml/')"
  outputpath="$outputxmldir/$outputfile"
  xsltproc \
    "$mydir/dita2docbook_template.xsl" \
    "$tmpdir/$sourcefile" \
    > "$outputpath"

  # Also generate list of output files for later reuse
  outputfiles="$outputfiles $outputpath"
  wellformcheck "$outputpath" "after conversion to DocBook"
done

## Create a very basic DC file

dcfile="$outputdirabs/$dcname"
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
  linkends=" $(xsltproc --stringparam 'name' 'linkend' $mydir/find.xsl $mydir/$outputfiles 2> /dev/null | tr '\n' ' ') "
fi


for outputpath in $outputfiles; do

  # FIXME: This currently leads to some text-completeness issues.
  xsltproc \
    "$mydir/clean-blocks.xsl" \
    "$outputpath" > "$outputpath.0"
  mv $outputpath.0 $outputpath

  wellformcheck "$outputpath" "after clean-blocks"

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

  wellformcheck "$outputpath" "after clean-ids"

  # FIXME: Hello insanity! Thy name is workaround. We have up to three
  # namespaces, so run three times. This avoids having to use
  # XSLT 2 but deserves a triple *facepalm* at least.
  # Hopefully, we can replace this mess with Python soon.
  # Also, I am doing that as the last trnasformation here, because otherwise,
  # this transformation is undone again by clean-blocks/clean-ids.
  thisfile=$(cat "$outputpath" | tr '\n' '\r' | sed -r \
    -e 's/(<[^>]+[ \t\r])xmlns(:[a-z]+)?="[^"]+"/\1/g' \
    -e 's/(<[^>]+[ \t\r])xmlns(:[a-z]+)?="[^"]+"/\1/g' \
    -e 's/(<[^>]+[ \t\r])xmlns(:[a-z]+)?="[^"]+"/\1/g' \
    | tr '\r' '\n')
  thisline=$(echo -e "$thisfile" | grep -m1 -n '<(section|chapter|preface|appendix)' | grep -oP '^[0-9]+')
  echo -e "$thisfile" | sed -r \
    -e "$thisline s_<(section|chapter|preface|appendix)_& xmlns=\"http://docbook.org/ns/docbook\" xmlns:xi=\"http://www.w3.org/2001/XInclude\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"_" \
    -e 's/(<[^>]+) +(>)/\1\2/g' \
    -e 's/(<[^>]+)  +([^>]+>)/\1 \2/g' \
    > "$outputpath.0"
  mv $outputpath.0 $outputpath

  wellformcheck "$outputpath" "after correcting xmlns"
done

[[ $verbose -eq 1 ]] && echo -e "FILES WE NEED (IMAGES, ETC.)\n\n$tmpdir/neededstuff\n"

## Copy replaced files

for replacedfile in $replacedfiles; do
  cp "$basedir/$replacedfile" "$outputxmldir/$replacedfile"
done

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

# Append keydef into entity file
# Search for this file in different parent directories:
keywords=$(searchparents "$keywords_default")

if [[ -f "$keywords" ]]; then
    [[ $verbose -eq 1 ]] && echo "Using keywords file $KEYWORDS"

    xsltproc -o $tmpdir/$ENTITYFILE \
        "$mydir/keyword2entity.xsl" $KEYWORDS
    cat $tmpdir/$ENTITYFILE >> $outputxmldir/$ENTITYFILE
fi

daps -d "$dcfile" xmlformat > /dev/null
daps -d "$dcfile" optipng > /dev/null

echo ""
echo "Output directory:    $outputdirabs"

if [[ ! $CLEANTEMP == 0 ]]; then
  rm -r $tmpdir
fi
