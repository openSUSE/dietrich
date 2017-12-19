#!/usr/bin/env python3
"""
A replacement for xsltproc with custom extension functions
"""

import argparse
import copy as _copy
import logging
from logging.config import dictConfig
from lxml import etree
import re
import sys

LOGGERNAME='pyproc'

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

#: the namespace for our extension function
EXTENSION_NS="urn:x-suse:python:dietrich"

XSLT_NS="http://www.w3.org/1999/XSL/Transform"

XSLT_ROOTS=(etree.QName(XSLT_NS, "stylesheet"), etree.QName(XSLT_NS, "transform"))


class PyProcXSLTError(etree.Error):
    def __init__(self, message, *, filename=None):
        super().__init__(message)
        self.filename = filename


class ParamAppendAction(argparse._AppendAction):
    """This action checks the --stringparam/--param option for
       invalid characters in the name argument.
    """
    def __call__(self, parser, namespace, values, option_string=None):
        name, value = values
        if re.search("[+:]", name):
            raise argparse.ArgumentError(self,
                                         "name %r in option --%s "
                                         "contains invalid character" \
                                          % (name, self.dest))
        super().__call__(parser, namespace, tuple(values), option_string)


def parse(cliargs=None):
    """Parse the command line

    :param list cliargs: command line arguments
    :return: parsed command line arguments as :class:`argparse.Namespace` object
    """
    parser = argparse.ArgumentParser(description='xsltproc replacement in Python3',
                                     # usage='%(prog)s [OPTIONS] STYLESHEET FILE',
                                     )
    parser.add_argument('--version', action='version', version='%(prog)s 2.0')
    parser.add_argument('-v', '--verbose',
                        action="count",
                        help="Raise verbosity level",
                        )
    parser.add_argument('-o', '--output',
                        # action="",
                        help="save to a given file"
                        )
    parser.add_argument('--encoding',
                        default="utf-8",
                        help='the input document character encoding'
                        )
    parser.add_argument('--param',
                        nargs=2,
                        action=ParamAppendAction, #'append',
                        help=("pass a (parameter,value) pair "
                              "name is a QName or a string of the form {URI}NCName. "
                              "value is an UTF8 XPath expression. "
                              "string values must be quoted like \"'string'\" or "
                              "use stringparam to avoid it"
                              )
                        )
    parser.add_argument('--stringparam',
                        nargs=2,
                        action=ParamAppendAction,  #'append',
                        help="pass a (parameter, UTF8 string value) pair"
                        )
    parser.add_argument('--nonet',
                        action="store_true",
                        default=False,
                        help="refuse to fetch DTDs or entities over network"
                        )
    parser.add_argument('--xinclude',
                        action="store_true",
                        default=False,
                        help="do XInclude processing on document input"
                        )
    parser.add_argument('xslt',
                        metavar="STLYESHEET",
                        help="the XSLT stylesheet"
                        )
    parser.add_argument('xml',
                        metavar="FILE",
                        help="the XML input"
                        )

    args = parser.parse_args(cliargs)
    # Setup logging and the log level according to the "-v" option
    dictConfig(DEFAULT_LOGGING_DICT)
    log.setLevel(LOGLEVELS.get(args.verbose, logging.DEBUG))
    log.info("CLI result: %s", args)
    return args


# -------------------------------------------------------------------
def py_normpath(context, node):
    """
    """
    log.info("Calling normpath with: %r", node)
    if isinstance(node, list) and isinstance(node[0], etree._Element):
        path = node[0].text
    elif isinstance(node, list) and isinstance(node[0], str):
        path = node[0]
    return path.upper()


# -------------------------------------------------------------------
def process(args):
    """Process the XML file with XSLT stylesheet

    :param args: the arguments from the argparse object
    :type args: :class:`argparse.Namespace`
    """
    parseroptions = dict(no_network=args.nonet,
                         # resolve_entities=args.resolve_entities,
                         # encoding=args.encoding,
                         )
    # prepare parser
    ns=etree.FunctionNamespace(EXTENSION_NS)
    ns.prefix = 'py'
    ns.update(dict(normpath=py_normpath))

    xmlparser = etree.XMLParser(**parseroptions)
    root = etree.parse(args.xml, parser=xmlparser)
    if args.xinclude:
        root.xinclude()
    xsltproc = etree.parse(args.xslt)
    if etree.QName(xsltproc.getroot()) not in XSLT_ROOTS:
        raise PyProcXSLTError("No stylesheet root tag found!", filename=args.xslt)

    xsltproc = etree.XSLT(xsltproc)
    resulttree = xsltproc(root)

    #result = etree.tostring(resulttree, encoding="unicode")
    if not args.output:
        sys.stdout.write(str(resulttree))
    else:
        resulttree.write_output(args.output)
        log.info("Result written to %r", args.output)


def main(cliargs=None):
    """main function of the script

    :param list cliargs: command line arguments
    :return: success (=0) or not
    """
    args = parse(cliargs)
    try:
        process(args)
    except (etree.XMLSyntaxError, PyProcXSLTError) as error:
        log.fatal(error)
        log.fatal("file: %r", error.filename)
        return 1
    except OSError as error:
        log.fatal(error)
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
