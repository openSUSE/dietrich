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
* Structure of document is not converted correctly: Main file shows a flat list of sections. -> Needs to be done via proper XSLT, map2docbook.xsl seems not to be willing
    * Idea:
        1. For the top-level includes, generate XIncludes
        2. Make sure that the top-level elements in each of the files matches the intended top-level.
        3. Generate file that lists for each file which XIncludes need to be appended to its content.
        4. Convert to DocBook.
        5. Add XIncludes to just before root element is closed.
* attempted intra-xrefs fail -- because the files are not collected in a `<set/>`, e.g.: tenantuser/about/c-about.xml : xref to "../../shared/intro/c-intro.xml", comes out with empty linkend -> hard to fix correctly, especially if we are thinking about shipping only part of the docs.
