## Enhancements
* support for DITA profiling attributes (?): audience platform product props otherprops rev
* given https://github.com/dita-ot/org.dita.docbook/commit/9cca1355 , can we
  convert the core conversion stuff back down to XSLT 1.0? If so, we'd be able
  to lose the saxon9 dependency and might be able to save some time
* convert to [DocBook 5](http://docserv.nue.suse.com/project_management/archive/github_migration/html/db4_to_db5.html)

## Known issues

* for image filerefs that are part of formerly conreffed content, the wrong
  path might be generated:
  * some of my conref marker comments are removed by the DITA->DocBook
    conversion stylesheets
  * we are not using a reliable method of retrieving the file names
  -> ideally, we should generate the list of needed images before the
    conversion when all the marker data is still intact or we could see if
    other types of markers are both workable and more reliable, such as e.g.
    tags.
* entity file does not contain anything (instead of containing conreffed
  content). This lowers editability of the converted content somewhat.
  * there is a WIP implementation for this in the branch entity-conversion-wip
  * the WIP currently mostly fails to work properly because the DITA->DocBook
    stylesheets remove some conref markers (see above)
  * additionally, some content that falls out of this may not be valid DocBook,
    because e.g. literal/phrase and other invalid constructs cannot be filtered
    any more
* attempted intra-xrefs fail -- because the files are not collected in a
  `<set/>`, e.g.: tenantuser/about/c-about.xml : xref to
  "../../shared/intro/c-intro.xml", comes out with empty linkend -> hard to
  fix properly correctly, especially if we are thinking about shipping only
  part of the docs. Maybe I can generate a citetitle?
* conref resolution works with imprecise IDs: only the last part of of a
  nested ID is actually used -- if a "bare" ID is available twice in the same
  XML, we might be importing the wrong part of the document
* the name dtdbcd is not memorable

## Issues that have been worked around

* Instead of `<sidebar/>`, we now use `<bridgehead/>`s, so we don't see the
  following issues any more:
  * suse-xsl issue or fop 1.1 issue? sidebar/itemizedlist/listitem comes out
    with negative margins between (some) listitems, sxsl2.0.6.3, fop1.1,
    osoperator, sec 1.2, "Monitoring" sidebar (PDF)
  * suse-xsl issue: sidebar titles are completely disfigured: whole text is
    generated for .number
