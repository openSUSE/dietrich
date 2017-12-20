#!/usr/bin/env python3

import argparse
from lxml import etree
import logging
from logging.config import dictConfig
import os
import re
import sys
import tempfile
import shutil

import pyproc

LOGGERNAME='dita2db'
SCRIPTDIR=os.path.dirname(os.path.realpath(__file__))
XSLTDIR=os.path.join(SCRIPTDIR, "xslt")

#: The dictionary, used by :class:`logging.config.dictConfig`
#: use it to setup your logging formatters, handlers, and loggers
#: For details, see https://docs.python.org/3.4/library/logging.config.html#configuration-dictionary-schema
DEFAULT_LOGGING_DICT = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {'format': '[%(levelname)s] %(name)s: %(message)s'},
    },
    'handlers': {
        'default': {
            'level': 'NOTSET',
            'formatter': 'standard',
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
       LOGGERNAME: {
            'handlers': ['default'],
            'level': 'INFO',
            'propagate': True
        }
    }
}

#: Map verbosity level (int) to log level
LOGLEVELS = {None: logging.WARNING,  # 0
             0: logging.WARNING,
             1: logging.INFO,
             2: logging.DEBUG,
             }

#: Instantiate our logger
log=logging.getLogger(LOGGERNAME)


DEFAULT_CONFIGFILENAME='conversion.cfg'


def parse_cli(cliargs=None):
    """Parse the command line

    :param list cliargs: command line arguments
    :return: parsed command line arguments as :class:`argparse.Namespace` object
    """
    parser = argparse.ArgumentParser(description='DITA to DocBook conversion',
                                     usage='%(prog)s [OPTIONS] DITAMAP',
                                     )
    parser.add_argument('--version', action='version', version='%(prog)s 2.0')
    parser.add_argument('-v', '--verbose',
                        action="count",
                        help="Raise verbosity level",
                        )
    parser.add_argument('-o', '--output',
                        # action="",
                        help='save to a given file'
                        )
    parser.add_argument('-c', '--configfile',
                        default=DEFAULT_CONFIGFILENAME,
                        help='the configuration file (default %(default)r)'
                        )

    group = parser.add_argument_group('Configuration Options')
    group.add_argument('--outputdir',
                       default='converted',
                       help=('the directory to place output in. '
                             'Can but does not have to exist. '
                             'Existing files will be overwritten mercilessly.'
                             ''
                             )
                        )
    group.add_argument('--styleroot',
                       help='Style root to write into the DC file  (default %(default)s)'
                       )
    group.add_argument('--cleantmp',
                       action='store_true',
                       default=False,
                       help='Delete temporary directory after conversion (default %(default)s)'
                       )
    group.add_argument('--cleanid',
                       action='store_true',
                       default=False,
                       help='Remove IDs that are not used as linkends (default %(default)s)'
                       )
    group.add_argument('--entityfile',
                       default='entities.xml',
                       help=('File name (not path!) of an external file '
                             'that will be included with all XML files. '
                             'To reuse an existing file, it has to'
                             'exist below [OUTPUTDIR]/xml, if it does not, '
                             'an empty file will be created. (default: %(default)r)'
                             )
                       )

    parser.add_argument('ditamap',
                        metavar="DITAMAP",
                        help="the DITAMap"
                        )
    args = parser.parse_args(cliargs)

    # This will be the configparser.ConfigParser object
    args.config = None
    # Prepare a Namespace object to store other content vor the conversion process
    args.conv = argparse.Namespace()

    # Setup logging and the log level according to the "-v" option
    dictConfig(DEFAULT_LOGGING_DICT)
    log.setLevel(LOGLEVELS.get(args.verbose, logging.DEBUG))
    pyproc.log.setLevel(LOGLEVELS.get(args.verbose, logging.DEBUG))
    log.info("CLI result: %s", args)

    return args


def parseconfig(args):
    """Parse the configuration file

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    log.debug("Trying to load configuration file...")
    import configparser
    args.config = configparser.ConfigParser()
    args.conv.basedir = os.path.dirname(os.path.realpath(args.ditamap))
    configfile = os.path.join(args.conv.basedir, DEFAULT_CONFIGFILENAME)
    # Make sure to read first the default config file from the directory where the DITAMap
    # is located; try the one that is given from the command line:
    cfg = args.config.read([configfile, args.configfile])
    if not cfg:
        raise FileNotFoundError("Configuration file not found: %r" % args.configfile)
    log.debug("Successfully read config file %r", args.configfile)

    # Prepare the variables and save them all in the args.conv (for conversion):
    dmap = args.config['DITA2DOCBOOK']
    args.conv.basename = os.path.splitext(os.path.basename(args.ditamap))[0]
    args.conv.dcfile = "%s%s%s" % (dmap.get('dcprefix', 'DC-'),
                                    args.conv.basename,
                                    dmap.get('dcsuffix', ''))
    args.conv.mainfile = "%s%s%s" % (dmap.get('mainprefix', 'MAIN.'),
                                    args.conv.basename,
                                    dmap.get('mainsuffix', ''))
    if os.path.isabs(args.outputdir):
        args.conv.projectdir = os.path.join(args.outputdir, args.conv.basename)
    else:
        args.conv.projectdir = os.path.join(args.conv.basedir, args.outputdir,
                                            args.conv.basename,
                                            )
    args.conv.xmldir = os.path.join(args.conv.projectdir, 'xml')

    # Get the filenames to be replaced. Save it as in the form:
    # [[old1, new1], [old2, new2], ...]
    args.conv.replacefiles = [ff for ff in dmap.get('replace', '').split("\n") if ff]
    args.conv.replacefiles = [re.split("\s*=\s*", ff) for ff in args.conv.replacefiles]
    # Get the filenames to be removed. Save it in a set to remove duplicates:
    args.conv.removefiles = set([ff for ff in dmap.get('remove', '').split("\n") if ff])

    # Save directory where this script is saved:
    args.conv.scriptdir = SCRIPTDIR
    return args.config


def debugconfig(args):
    """Output configuration options, if needed

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    dmap = args.config['DITA2DOCBOOK']
    log.info("== Configuration options ==")
    log.info("   outputdir: %r", dmap.get('outputdir', args.outputdir))
    log.info("  entityfile: %r", dmap.get("entityfile", args.entityfile))
    log.info("   styleroot: %r", dmap.get('styleroot', args.styleroot))
    log.info("    cleantmp: %s", dmap.get('cleantmp', args.cleantmp))
    log.info("     cleanid: %s", dmap.get('cleanid', args.cleanid))
    log.info("       tweak: %s", dmap.get('tweak', None))
    log.info("     basedir: %r", args.conv.basedir)
    log.info("    basename: %r", args.conv.basename)
    log.info("      dcfile: %r", args.conv.dcfile)
    log.info("  projectdir: %r", args.conv.projectdir)
    log.info("      xmldir: %r", args.conv.xmldir)
    log.info("    mainfile: %r", args.conv.mainfile)
    log.info("     replace: %s", args.conv.replacefiles)
    log.info("      remove: %r", args.conv.removefiles)
    log.info("   scriptdir: %r", SCRIPTDIR)
    log.info("     xsltdir: %r", XSLTDIR)
    log.info("--------------------------------------")


def xmlparser_args(args):
    """Create default Namespace for XMLParser

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
     :return: :class:`argparse.Namespace` for XMLParser
    """
    return argparse.Namespace(xinclude=False,
                              nonet=True, # => no_network
                              # output=None,
                              novalid=True,
                              # load_dtd=True,
                              # resolve_entities=True,
                              stringparam=None,
                              param=None,
                              xsltresult=True
                              )


def create_mainfile(args):
    """Create the MAIN*.xml file

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
     :return: list of source files and replaced files
    """
    log.info("=== Creating MAIN file...")
    procargs=xmlparser_args(args)
    procargs.xml=args.ditamap
    procargs.xsltresult=True
    procargs.xslt=os.path.join(XSLTDIR, "map-to-MAIN.xsl")
    procargs.output=os.path.join(args.conv.xmldir, args.conv.mainfile)
    procargs.stringparam={'prefix': args.conv.basename,
                          'entityfile': args.entityfile,
                          }
    # procargs.resolve_entities=True

    os.makedirs(args.conv.xmldir, exist_ok=True)
    xslt, transform = pyproc.process(procargs)
    log.debug("Wrote %r", procargs.output)

    # Currently, the stylesheet outputs other important information with xsl:message
    # We need to save it in the $TMPDIR/includes
    tmpincludes=os.path.join(args.conv.tmpdir, "includes")
    sourcefiles=[]
    replacedfiles=[]
    with open(tmpincludes, "w") as fh:
        for entry in transform.error_log:
            line = entry.message
            fh.write("%s\n" % line)
            ## Find the source files in the ditamap
            if line.startswith('source-file:'):
                sourcefiles.append(line.replace('source-file:', ''))
            if line.startswith('source-file-replaced:'):
               replacedfiles.append(line.replace('source-file-replaced::', ''))

    log.debug("Wrote %r", tmpincludes)
    # In-place sorting
    sourcefiles.sort()
    replacedfiles.sort()
    return sourcefiles, replacedfiles


def hasconref(node):
    """Checks wheather the node has a conref attribute, regardless of the depth

    :param node: the node or tree
    :type node: :class:`lxml.etree._ElementTree` | :class:`lxml.etree._Element`
    :return: True if there is at least one conref attribute there, otherwise False
    :rtype: bool
    """
    return bool(node.xpath('//*[@conref]'))


def include_conrefs(args, sourcefiles, replacedfiles):
    """Resolve DITA's conref attribute

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    log.info("=== Resolving conrefs...")
    log.debug("sourcefiles: %s", sourcefiles)
    log.debug("replacedfiles: %s", replacedfiles)

    #for sourcefile in $sourcefiles; do
    #  mkdir -p "$tmpdir/$(dirname $sourcefile)"
    #  xsltproc \
    #    --stringparam "basepath" "$basedir"\
    #    --stringparam "relativefilepath" "$(dirname $sourcefile)"\
    #    "$mydir/resolve-conrefs.xsl" \
    #    "$basedir/$sourcefile" > "$tmpdir/$sourcefile"
    #
    # All uncommented lines are replaced inside the for-loop:
    procargs = xmlparser_args(args)
    procargs.xslt=os.path.join(XSLTDIR, "resolve-conrefs.xsl")
    procargs.stringparam={'basepath': args.conv.basedir,
                          }
    failedfiles=[]
    for sf in sourcefiles:
        sfdir=os.path.dirname(sf)
        os.makedirs(os.path.join(args.conv.tmpdir, sfdir), exist_ok=True)
        procargs.stringparam['relativefilepath'] = sfdir
        procargs.xml = os.path.join(args.conv.basedir, sf)
        procargs.output = os.path.join(args.conv.tmpdir, sf)

        log.debug("Transforming %r...", sf)
        try:
            xslt, transform = pyproc.process(procargs)
        except etree.XSLTApplyError as error:
            log.fatal(error)
            failedfiles.append(sf)
            log.fatal("Current source file: %r", sf)
            log.fatal(" procargs: %s", procargs)
            cmd=("xsltproc --stringparam basepath {basepath} "
                 "--stringparam relativefilepath {relativefilepath} "
                 "{xslt} {xml} > {sourcefile}")
            cmd = cmd.format(basepath=procargs.stringparam['basepath'],
                       relativefilepath=procargs.stringparam['relativefilepath'],
                       xslt=procargs.xslt,
                       xml=procargs.xml,
                       sourcefile=procargs.output,
                       )
            log.fatal("You can try it with: %s", cmd)
        else:
            log.debug("Transformed %r", sf)

        xml = etree.parse(procargs.output)
        if hasconref(xml):
            # FIXME
            log.warning("File %r needs another round of conref resolution", sf)

    #  # Rinse and repeat while there are still conrefs left. This is dumb but
    #  # effective and does not involve overly complicated XSLT.
    #  while [[ $(xmllint --xpath '//*[@conref]' "$tmpdir/$sourcefile" 2> /dev/null) ]]; do
    #    xsltproc \
    #      --stringparam "basepath" "$basedir"\
    #      --stringparam "relativefilepath" "$(dirname $sourcefile)"\
    #      "$mydir/resolve-conrefs.xsl" \
    #      "$tmpdir/$sourcefile" > "$tmpdir/$sourcefile-0"
    #    mv "$tmpdir/$sourcefile-0" "$tmpdir/$sourcefile"
    #  done
    #done

    if failedfiles:
        log.critical("Failed files: %s", failedfiles)
    else:
        log.debug("All files were transformed! :-)")


def make_unique_ids(args):
    """Modify the original DITA files to get rid of duplicate IDs

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    pass


def create_dcfile(args):
    """Create a very basic DC file

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    log.info("=== Creating DC file %r", args.conv.dcfile)
    dcfile = os.path.join(args.conv.projectdir, args.conv.dcfile)
    with open(dcfile, 'w') as fh:
        fh.write("## -----------------------------------------\n")
        fh.write("## Doc Config File\n")
        fh.write("## From DITAMap %s\n" % args.conv.basename)
        fh.write("## -----------------------------------------\n")
        fh.write("##\n\n")
        fh.write("MAIN=%s\n" % args.conv.mainfile)
        fh.write("# ROOTID=\n")
        if args.styleroot:
            fh.write("STYLEROOT=%s\n" % args.styleroot)


def convert2db(args, sourcefiles):
    """Actual conversion from DITA to DocBook
    """
    ## Actual conversion
    #outputfiles=""
    #for sourcefile in $sourcefiles; do
    #  # We need the name of the ditamap in here, because you might want to
    #  # generate DocBook files for multiple ditamaps into the same directory, if
    #  # these files then overwrite each other, we might run into issue because
    #  # they might include wrong XIncludes (which we might not even notice) or
    #  # wrong root elements (which we are more likely to notice)
    #  outputfile="${inputbasename}-$(echo $sourcefile | sed -r 's_[/, ]_-_g')"
    #  outputpath="$outputxmldir/$outputfile"
    #  saxon9 -xsl:"$mydir/dita2docbook_template.xsl" -s:"$tmpdir/$sourcefile" -o:"$outputpath"
    #
    #  # Also generate list of output files for later reuse
    #  outputfiles="$outputfiles $outputpath"
    #done
    outputfiles=[]



def main(cliargs=None):
    """main function of the script

    :param list cliargs: command line arguments
    :return: success (=0) or not
    """
    args = parse_cli(cliargs)
    try:
        parseconfig(args)
        debugconfig(args)
        args.conv.tmpdir = tempfile.mkdtemp(suffix="db-convert")
        log.info("Created temp directory: %r", args.conv.tmpdir)
        sourcefiles, replacedfiles = create_mainfile(args)
        include_conrefs(args, sourcefiles, replacedfiles)
        create_dcfile(args)

        if args.cleantmp:
            shutil.rmtree(args.conv.tmpdir)

    except FileNotFoundError as error:
        log.fatal(error)
        return 10

    return 0


if __name__ == "__main__":
    sys.exit(main())
