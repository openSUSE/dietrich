## Known to work for

* fujitsu-cmm: overview.ditamap

## Known issues

* Entity file needs to be manually updated
* Structure of document is not converted correctly: Main file shows a flat list of sections.
* xref: IDREF attribute linkend references an unknown ID "", e.g., tenantuser-about-c-about.xml:23 -- probably need to make sure there always is an ID on the top-level element (before converting to DocBook but those also need to be kept during the clean-ids.xsl step!).
* apparently inlinemediaobject without a para around them, e.g., tenantuser-access-c-tuaccess.xml:22
