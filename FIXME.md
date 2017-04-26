## Enhancements
* support for DITA profiling attributes (?): audience platform product props otherprops rev
* support for excluding/replacing sections (?)

## Known issues

* Entity file does not contain anything (instead of containing conreffed content). This lowers editability of the converted content somewhat.
    * Crazy-town solution:
        1. Use Saxon to find out where an ID comes from (i.e. line and char numbers of containing elements begin and end). (Hope that Saxon does not change the line numbers by just reading the file in.)
        2. Add markers before & after conreffed elements using e.g. sed, to avoid modifying stuff with XML tools. Markers should already contain the expected entity name.
        3. Convert to DocBook.
        4. Move content from inside markers into entities (and replace original occurrence with an entity too)
        5. Make sure that entities do not contain IDs.
    * Caveats:
        * Need to be able to expand the list of source files, since original content may come from files that are not part of the source
    * Other possible solution:
* attempted intra-xrefs fail -- because the files are not collected in a
  `<set/>`, e.g.: tenantuser/about/c-about.xml : xref to
  "../../shared/intro/c-intro.xml", comes out with empty linkend -> hard to
  fix properly correctly, especially if we are thinking about shipping only
  part of the docs. Maybe I can generate a citetitle?

## Issues that have been worked around

* Instead of `<sidebar/>`, we now use `<bridgehead/>`s, so we don't see the
  following issues any more:
  * suse-xsl issue or fop 1.1 issue? sidebar/itemizedlist/listitem comes out
    with negative margins between (some) listitems, sxsl2.0.6.3, fop1.1,
    osoperator, sec 1.2, "Monitoring" sidebar (PDF)
  * suse-xsl issue: sidebar titles are completely disfigured: whole text is
    generated for .number
