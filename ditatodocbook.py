#!/usr/bin/env python3

import argparse
import collections
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
XMLBASE=etree.QName('http://www.w3.org/XML/1998/namespace', 'base')

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
    group.add_argument('--tmpdir',
                       default=None,
                       help='Define your own temporary directory'
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
            # FIXME: this is (maybe) another rinse and repeat strategy
            log.warning("File %r needs another round of conref resolution", sf)

    if failedfiles:
        log.critical("Failed files: %s", failedfiles)
    else:
        log.debug("All files were transformed! :-)")


def make_unique_ids(args, sourcefiles):
    """Modify the original DITA files to get rid of duplicate IDs

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
     :param list sourcefiles: a list of sourcefile
    """
    log.info("=== Making IDs unique")
    tmpsourcefiles = [os.path.join(args.conv.tmpdir, s) for s in sourcefiles]
    procargs = xmlparser_args(args)
    xmlparser = pyproc.create_xmlparser(procargs)
    allids=[]
    for tmp in tmpsourcefiles:
        root = etree.parse(tmp, parser=xmlparser)
        allids.extend(root.xpath('//@id|//@xml:id'))
    allids.sort()
    # We are only interested in IDs which occurs more than once
    nonuniqueids=[key for key, value in collections.Counter(allids).items() if value > 1]
    nonuniqueids=" ".join(nonuniqueids)
    # log.debug("non unique id's: %s", nonuniqueids)
    # procargs=xmlparser_args(args)
    procargs.xslt=os.path.join(XSLTDIR, "create-unique-ids.xsl")
    for sf in sourcefiles:
        procargs.xml=os.path.join(args.conv.tmpdir, sf)
        procargs.output="%s-0" % procargs.xml
        procargs.stringparam={'nonuniqueids': nonuniqueids,
                              'self': sf,
                              'prefix': args.conv.basedir,
                              }
        # log.debug("  parser args: %s", procargs)
        xslt, transform = pyproc.process(procargs)
        log.debug("Make unique IDs for %r", procargs.xml)
        for entry in transform.error_log:
            log.debug(entry.message)
        os.rename(procargs.output, procargs.xml)


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


def collect_linkends(args, outputfiles):
    """Collect all linkends of the converted files (FIXME)

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    log.info("=== Collecting linkends...")
    linkends=[]
    if not args.cleanid:
        return linkends
    for output in outputfiles:
        # FIXME: Need to create a root object first and iterate
        # over linkend attributes:
        # linkends.extend(root.xpath("//@linkend"))


def copyimages(args):
    """Copy all image files FIXME

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    log.info("=== Copying images...")
    pass


def convert2db(args, sourcefiles):
    """Actual conversion from DITA to DocBook (FIXME)

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
     :param list sourcefiles: a list of sourcefiles
    """
    log.info("=== Creating DocBook files")
    outputfiles=[]
    # HINT: Maybe use saxon9 to convert this?

def get_ditafiles(args):
    """Get all .dita files

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
     :yield: a relative path to a .dita file
    """
    #
    log.info("=== Get all ditafiles")
    startdir=os.path.dirname(args.ditamap)
    # If ditamap is in current directory, .dirname() provides an empty string:
    startdir="." if not startdir else startdir
    log.debug("startdir=%r", startdir)
    for root, directories, filenames in os.walk(startdir):
         for f in filenames:
             if not f.endswith(".dita"):
                continue
             # log.info(os.path.join(root, f))
             yield os.path.join(root, f)


def investigate_ditafiles(args):
    """

     :param args: the arguments from the argparse object
     :type args: :class:`argparse.Namespace`
    """
    root = etree.XML("<root/>")
    root.attrib['version'] = "1.0"

    # Create XML parser:
    procargs = xmlparser_args(args)
    xmlparser = pyproc.create_xmlparser(procargs)

    for ditafile in get_ditafiles(args):
        log.debug(ditafile)
        try:
            dita = etree.parse(ditafile, xmlparser)
            df = etree.Element("ditafile")
            df.attrib[XMLBASE.text] = os.path.dirname(ditafile)
            df.attrib['href'] = os.path.basename(ditafile)

            # Create a list of all @conref attributes in this dita file:
            df_conrefs = etree.SubElement(df, 'conrefs')
            for conrefattr in dita.xpath("//*/@conref"):
                # <conref orig="original_path">normpath</conref>
                c = etree.SubElement(df_conrefs, "conref")
                c.attrib['orig'] = conrefattr
                # Normalize the conref path
                # TODO: What about the fragments? (= string after the '#')
                c.text = os.path.normpath(os.path.join(df.attrib[XMLBASE.text], conrefattr))

            # Create a list of all id and xml:id attributes in this dita file:
            df_ids = etree.SubElement(df, 'ids')
            for idattr in dita.xpath("//*/@id| //*/@xml:id"):
                i = etree.SubElement(df_ids, "i")
                i.text = idattr

            # Create a list of all keywords in this dita file:
            df_kws = etree.SubElement(df, 'keywords')
            # Make @keyref
            for keyref in set(dita.xpath("//*/@keyref")):
                kref = etree.SubElement(df_kws, "keyref")
                kref.text = keyref
            root.append(df)
        except etree.XMLSyntaxError as error:
            log.error(error)

    tree = root.getroottree()
    ditasummary = os.path.join(args.conv.tmpdir, "ditasummary.xml")
    tree.write(ditasummary, pretty_print=True, encoding="utf-8")
    log.debug("Written a DITA summary to %r", ditasummary)


def main(cliargs=None):
    """main function of the script

    :param list cliargs: command line arguments
    :return: success (=0) or not
    """
    args = parse_cli(cliargs)
    try:
        parseconfig(args)
        debugconfig(args)
        if args.tmpdir is None:
            args.conv.tmpdir = tempfile.mkdtemp(suffix="db-convert")
        else:
            args.conv.tmpdir = args.tmpdir
            os.makedirs(args.tmpdir, exist_ok=True)
        log.info("Created temp directory: %r", args.conv.tmpdir)
        sourcefiles, replacedfiles = create_mainfile(args)
        include_conrefs(args, sourcefiles, replacedfiles)
        create_dcfile(args)
        make_unique_ids(args, sourcefiles)
        investigate_ditafiles(args)

        if args.cleantmp:
            shutil.rmtree(args.conv.tmpdir)

    except FileNotFoundError as error:
        log.fatal(error)
        return 10

    return 0


if __name__ == "__main__":
    sys.exit(main())
