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
#     + CLEANID: Remove IDs that are not used as linkends. (default: 1)
#     + ENTITYFILE: File name (not path!) of an external file that will be
#         included with all XML files. To reuse an existing file, it has to
#         exist below [OUTPUTDIR]/xml, if it does not, an empty file will be
#         created. (default: "entities.ent")
#     + OUTPUTDIR: The directory to place output in. Can but does not have to
#         exist. Existing files will be overwritten mercilessly.
#         (default: [DITAMAP's_DIR]/converted/[DITAMAP's_NAME])
#     + STYLEROOT: Style root to write into the DC file. (default: [none])
#     + TWEAK: Space-separated list of vendor tweaks to apply.
#         (default: [none], available:
#           "fujitsu" - convert emphases starting with "PENDING:" to <remark/>s,
#              remove emphases from link text
#         )
#
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
# Developer Configuration:
#     + CLEANTEMP: Delete temporary directory after conversion. (default: 1)
#     + TEMPDIR: Set a fixed directory for temporary files.
#         (default: random directory under /tmp/)
#     + WAITONLOG: Wait for input after every log message. Very annoying but
#         can be helpful for debugging. (default: 0)

#
# Package Dependencies on openSUSE:
#   daps dita ImageMagick


## This script
me="$(test -L $(realpath $0) && readlink $(realpath $0) || echo $(realpath $0))"
mydir="$(dirname $me)"
config="conversion.conf"

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
CLEANID=0
TWEAK=""
ENTITYFILE="entities.ent"
WAITONLOG=0

# --

function log() {
  # $1 - message
  # $2 - keep line open? 0 (default) - no, 1 - yes
  xp=''
  [[ $2 -eq 1 ]] && xp='n'
  [[ $verbose -eq 1 ]] && >&2 echo -e${xp} "$1"
  [[ $WAITONLOG -eq 1 ]] && read x
}

function logdone() {
  log " [done]"
}

function err() {
  # $1 message
  # $2 0 (default) - non-fatal, 1 - fatal
  >&2 echo -e "(meh) $1"
  [[ $2 -eq 1 ]] && exit 1
}

function mv0() {
  # $1 - path to move to
  mv "${1}.0" "${1}"
}

function readconfig() {
  # $1 - (relative configuration file path)

  # Sourcing is a security issue but let's ignore that for the moment.
  if [[ -s "$1" ]]; then
    options="$(sed -rn '/#!/{n; p; :loop n; p; /^[ \t]*$/q; b loop}' $0 | sed -r -n 's/^# +\+ ([^:]+):.*/\1/ p' | tr '\n' '|' | sed -r -e "s/\[DITAMAP\]/$inputbasename/g" -e 's/\|$//')"
    recognized=$(sed -rn "s/[ \t]*($options)=.*/\1/ p" "$1" | tr '\n' ' ')
    log "Available options: $(echo $options | sed -r 's/\|/ /g')"
    log "Options recognized in $config: $recognized"
    log "\n  (For information, see --help.)"
    . "$1" || true
  else
    log "Did not find $config: Using default settings."
  fi
}

function checkreplacements() {
  # $1 - list of replacement files read from config

  replacements="$(echo $replace | sed -r 's@( |^)[^= ]+=@ @g')"
  replacementnotfound=0
  for replacement in $replacements; do
    if [[ ! -f "$basedir/$replacement" ]]; then
      err "Replacement file does not exist: $basedir/$replacement"
      replacementnotfound=1
    fi
  done
  if [[ $replacementnotfound == 1 ]]; then
    err "Replacement file(s) not found. Check your $config. Quitting."
  fi
}

function createtemp() {
  if [[ ! $TEMPDIR ]]; then
    tmpdir=$(mktemp -d -p '/tmp' -t 'db-convert-XXXXXXX')
  else
    rm -rf "$TEMPDIR/*" 2> /dev/null
    mkdir -p "$TEMPDIR"
    tmpdir="$TEMPDIR"
  fi
}

function createmain() {
  mainfile="$outputxmldir/$mainname"
  log "Writing MAIN file $mainfile." 1

  # --novalid is necessary for the Fujitsu stuff since we seem to lack the right DTD
  xsltproc --novalid \
    --stringparam "prefix" "$inputbasename" \
    --stringparam "entityfile" "$ENTITYFILE" \
    --stringparam "replace" " $replace " \
    --stringparam "remove" " $remove " \
    "$mydir/map-to-MAIN.xsl" \
    "$inputmap" > "$mainfile" 2> "$tmpdir/includes"

  logdone
}

function findincludes() {
  # $1 - classification of include file to look for
  sed -n -r 's/^'"$1"':// p' $tmpdir/includes
}

function resolveconrefs() {
  log "Resolving conrefs in" 1

  for sourcefile in $sourcefiles; do
    log " $sourcefile" 1
    mkdir -p "$tmpdir/$(dirname $sourcefile)"
    cp "$basedir/$sourcefile" "$tmpdir/$sourcefile"

    # Rinse and repeat while there are still conrefs left. This is dumb but
    # effective and does not involve overly complicated XSLT.
    while [[ $(xmllint --xpath '//*[@conref]' "$tmpdir/$sourcefile" 2> /dev/null) ]]; do
      xsltproc \
        --stringparam "basepath" "$basedir"\
        --stringparam "relativefilepath" "$(dirname $sourcefile)"\
        "$mydir/resolve-conrefs.xsl" \
        "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile.0"
      mv0 "$tmpdir/$sourcefile"
    done
  done

  logdone
}

# FIXME: This is unmitigated nonsense...
function searchfilepath() {
  # $1 - file name to look for
  path=''
  for parent in "." ".." "../.."; do
    if [[ -f $parent/$1 ]]; then
      path="$basedir/$parent/$CONKEYREFS"
      break
    fi
  done
  if [[ "$path" != '' ]]; then
    echo "$path"
  else
    log "Searched for file $1 but did not find it."
  fi
}

function resolveconkeyrefs() {
  if [[ -f "$CONKEYREFS" ]]; then
    for sourcefile in $sourcefiles; do
       log "Resolving conkeyrefs for $sourcefile"
       xsltproc \
         --stringparam conrefs.file $CONKEYREFS \
        "$mydir/resolve-conkeyref.xsl" \
         "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile.0"
       mv0 "$tmpdir/$sourcefile"
    done
  fi
}

function createconrefentities() {
  if [[ -f "$KEYWORDS" ]]; then
      echo "Using keywords file $KEYWORDS"

      xsltproc -o $tmpdir/$ENTITYFILE \
          "$mydir/keyword2entity.xsl" $KEYWORDS
      cat $tmpdir/$ENTITYFILE >> $outputxmldir/$ENTITYFILE
  fi
}


function dedupeids() {
  tempsourcefiles=$(echo $sourcefiles | sed -r "s,[^ ]+,$tmpdir/&,g")
  allids=$(xsltproc --stringparam 'name' 'id' $mydir/find.xsl $tempsourcefiles 2> /dev/null | sort)
  nonuniqueids=$(echo -e "$allids" | uniq -d | tr '\n' ' ')

  log "Deduplicating IDs" 1

  for sourcefile in $sourcefiles; do
      xsltproc \
        --stringparam "nonuniqueids" "$nonuniqueids"\
        --stringparam "self" "$sourcefile"\
        --stringparam "prefix" "$inputbasename"\
        "$mydir/create-unique-ids.xsl" \
        "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile.0"
      mv0 "$tmpdir/$sourcefile"
  done

  logdone
}

function converttodocbook() {
  log "Converting to DocBook" 1

  for sourcefile in $sourcefiles; do
    log " $sourcefile" 1
    # We need the name of the ditamap in here, because you might want to
    # generate DocBook files for multiple ditamaps into the same directory, if
    # these files then overwrite each other, we might run into issue because
    # they might include wrong XIncludes (which we might not even notice) or
    # wrong root elements (which we are more likely to notice)
    outputfile="${inputbasename}-$(echo $sourcefile | sed -r 's_[/, ]_-_g')"
    outputpath="$outputxmldir/$outputfile"
    xsltproc \
      "$mydir/dita2docbook_template.xsl" \
      "$tmpdir/$sourcefile" \
      > "$outputpath"

    # Also generate list of output files for later reuse
    outputfiles="$outputfiles $outputpath"
  done

  logdone
}

function createdc() {
  dcfile="$outputdirabs/$dcname"
  {
    echo "MAIN=$mainname"
    if [[ $STYLEROOT != '' ]]; then
      echo "STYLEROOT=$STYLEROOT"
    fi
  } > "$dcfile"
}

function cleanupdocbook() {
  collectlinkends

  log "Cleaning up generated DocBook files" 1

  for outputpath in $outputfiles; do

    log " $outputpath" 1

    log "(cleaning blocks" 1
    cleanblocks

    log "/IDs & elements" 1
    cleanelements

    log "/namespaces)" 1
    cleanns

  done

  logdone
}

function collectlinkends() {
  # By default, let's not clean up IDs...
  linkends=""
  if [[ $CLEANID == 1 ]]; then
    # Spaces at the beginning/end are intentional & necessary for XSLT later.
    linkends=" $(xsltproc --stringparam 'name' 'linkend' $mydir/find.xsl $mydir/$outputfiles 2> /dev/null | tr '\n' ' ') "
  fi
}

function cleanblocks() {
  # FIXME: This currently leads to some text-completeness issues.
  xsltproc \
    "$mydir/clean-blocks.xsl" \
    "$outputpath" > "$outputpath.0"
  mv0 $outputpath
}

function cleanelements() {
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
  mv0 $outputpath
}

function cleanns() {
  # FIXME: Hello insanity! Thy name is workaround. We have up to three
  # namespaces, so run three times. This avoids having to use
  # XSLT 2 but deserves a triple *facepalm* at least.
  # Hopefully, we can replace this mess with Python soon.
  # Also, I am doing that as the last transformation here, because otherwise,
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
  mv0 $outputpath
}

function copyimages() {
  log "Copying images" 1
  # For images, we do not yet generate file names that include the name of the
  # ditamap file. However, since images don't change with profiling/ditamap
  # content etc., that should not matter.
  imagesneeded="$(cat $tmpdir/neededstuff | sed -n 's/need-image:// p' | sort | uniq)"
  for image in $imagesneeded; do
    sourceimage="$(echo $image | sed -r 's/^[^,]+,(.*)$/\1/')"
    outputimage="$(echo $image | sed -r 's/^([^,]+).*$/\1/')"
    imagetype="$(echo $outputimage | grep -ioP '[a-z0-9]+$' | sed -r -e 's/[A-Z]/\L&/g' -e 's/jpeg/jpg/')"

    log " $sourceimage" 1

    mkdir -p "$outputimagedir/$imagetype" 2> /dev/null
    if [[ -f "$basedir/$sourceimage" ]]; then
      if [[ $imagetype == 'png' ]] || [[ $imagetype == 'jpg' ]]; then
        # Throw out everything we don't need for building books because FOP might
        # later choke on non-standard stuff.
        convert "$basedir/$sourceimage" -strip "$outputimagedir/$imagetype/$outputimage"
      else
        cp "$basedir/$sourceimage" "$outputimagedir/$imagetype/$outputimage"
      fi
    else
      err "Image $basedir/$sourceimage could not be found."
    fi
  done

  logdone
}

function finaldaps() {
  # $1 - DC file
  log "Running final optimizations with DAPS." 1

  xp=''
  [[ $verbose -eq 1 ]] && xp="-vv"

  dapsmessages=$(daps -d "$1" $xp xmlformat 2>/dev/stdout)
  dapsmessages+=$(daps -d "$1" $xp optipng 2>/dev/stdout)

  logdone
  log "$dapsmessages"
}

# --

## Source a config file, if there is any
readconfig "$basedir/$config"


OUTPUTDIR=$(echo "$OUTPUTDIR" | sed -r -e 's_^file:/+_/_' -e 's_/$__')

outputdirabs="$basedir/$OUTPUTDIR"
if [[ $OUTPUTDIR = /* ]]; then
  outputdirabs="$OUTPUTDIR"
fi

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

checkreplacements "$replace"

## Create temporary/output dirs
createtemp

mkdir -p "$outputxmldir"

echo ""

log "Temporary directory: $tmpdir"

## From the ditamap, create a MAIN file.
createmain

## Find the source files in the ditamap
sourcefiles=$(findincludes "source-file")
replacedfiles=$(findincludes "source-file-replaced")

# Include conrefs

resolveconrefs

# Include conkeyrefs
# FIXME: special case with hard-coded file name only
# FIXME: this is also a nonsense implementation
CONKEYREFS="HOS-conrefs.xml"
# Search for this file in different parent directories:
CONKEYREFS=$(searchfilepath "$CONKEYREFS")

resolveconkeyrefs

## Modify the original DITA files to get rid of duplicate IDs.
dedupeids

## Actual conversion
outputfiles=""
converttodocbook

## Create a very basic DC file
createdc

## Collect linkends, clean up all the IDs that are not used, also clean up
## filerefs in imageobjects and replace ex-conref'd contents with entities.
cleanupdocbook

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
copyimages

# Append keydef into entity file
# FIXME: Nonsense implementation
KEYWORDS="HOS-keywords.xml"
# install_entryscale_kvm twosystems hw_support_hardwareconfig

# Search for this file in different parent directories:
KEYWORDS=$(searchfilepath "$KEYWORDS")
createconrefentities

# Optipng & format files
finaldaps "$dcfile"

echo ""
echo "Output directory:    $outputdirabs"

if [[ ! $CLEANTEMP == 0 ]]; then
  rm -r $tmpdir
fi
