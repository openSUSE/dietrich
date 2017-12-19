#!/usr/bin/env python3
"""
A replacement for xsltproc with custom extension functions
"""

import argparse
import copy as _copy
from lxml import etree
import re
import sys

EXTENSION_NS="urn:x-suse:python:dietrich"



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
    return args


def process(args):
    """Process the XML file with XSLT stylesheet

    :param args: the arguments from the argparse object
    :type args: :class:`argparse.Namespace`
    """
    parseroptions = dict(no_network=args.nonet,
                         # resolve_entities=,
                         # encoding=args.encoding,
                         )
    xmlparser = etree.XMLParser(**parseroptions)
    root = etree.parse(args.xml, parser=xmlparser)
    if args.xinclude:
        root.xinclude()
    xsltproc = etree.parse(args.xslt)
    
    xsltproc = etree.XSLT(xsltproc)
    print(">>>", xsltproc, file=sys.stderr)
    resulttree = xsltproc(root)

    print(">>>", args.output, file=sys.stderr)
    result = etree.tostring(resulttree, encoding="unicode")
    if not args.output:
        sys.stdout.write(result)
    else:
        with open(args.output, mode="w") as fh:
            fh.write(result)


def main(cliargs=None):
    args = parse(cliargs)
    print(args)
    try:
        process(args)
    except etree.XMLSyntaxError as error:
        print(error, file=sys.stderr)
        print("file: %r" % error.filename, file=sys.stderr)
    except OSError as error:
        print(error, file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
