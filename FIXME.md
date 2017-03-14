## Known to work for

* fujitsu-cmm: overview.ditamap

## Known issues

* Entity file needs to be manually updated. Not an issue with overview.ditamap, but definitely an issue with all others.
    * Crazy-town solution:
        1. Use Saxon to find out where an ID comes from (i.e. line and char numbers of containing elements begin and end). (Hope that Saxon does not change the line numbers by just reading the file in.)
        2. Add markers before & after conreffed elements using e.g. sed, to avoid modifying stuff with XML tools. Markers should already contain the expected entity name.
        3. Convert to DocBook.
        4. Move content from inside markers into entities (and replace original occurrence with an entity too)
        5. Make sure that entities do not contain IDs.
    * Caveats:
        * Need to be able to expand the list of source files, since original content may come from files that are not part of the source
    * Other possible solution:
        * Do a preparation step before converting that just uses the document() function liberally and is able to include such sections
        * Not ideal for re-use, especially not having product name/product number entities might hurt
        * Side effects might be somewhat mitigated by including comments of where contents appear elsewhere
* Structure of document is not converted correctly: Main file shows a flat list of sections. -> Needs to be done via proper XSLT, map2docbook.xsl seems not to be willing
    * Idea:
        1. For the top-level includes, generate XIncludes
        2. Make sure that the top-level elements in each of the files matches the intended top-level.
        3. Generate file that lists for each file which XIncludes need to be appended to its content.
        4. Convert to DocBook.
        5. Add XIncludes to just before root element is closed.
* attempted intra-xrefs fail -- because the files are not collected in a
  `<set/>`, e.g.: tenantuser/about/c-about.xml : xref to
  "../../shared/intro/c-intro.xml", comes out with empty linkend -> hard to
  fix properly correctly, especially if we are thinking about shipping only
  part of the docs. Maybe I can generate a citetitle?
* having an absolute path function in XSLT would really help for both getting
  the image paths right and for getting conref paths/entities right, would
  need to feed the stylesheet the pcur=$(dirname path/to/current.file), then
  I could concat($pcur, '/', (@href|@fileref)[1]) = path/to/../../other/path.
  With substring-before('../') and string-after('../'), I should then be able
  to always eliminate pairs of dir/ + ../
