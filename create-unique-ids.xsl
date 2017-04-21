<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <xsl:param name="nonuniqueids" select="''"/>
  <xsl:param name="nonuniqueids-spaced" select="concat(' ', $nonuniqueids, ' ')"/>
  <xsl:param name="self" select="'me.xml'"/>

  <xsl:template match="/" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@id|@xml:id">
    <xsl:attribute name="{name(.)}">
      <xsl:choose>
        <xsl:when test="not(contains($nonuniqueids-spaced, concat(' ', ., ' ')))">
          <xsl:value-of select="."/>
        </xsl:when>
        <xsl:otherwise>
          <!-- We could use generate-id() here but what we really want are
          IDs that are reproducible across builds because that helps a lot as
          soon as you have to create a diff of the output.
          The promise of generate-id() that it generates unique IDs is
          worthless to us anyway since we don't process the document all at
          once but in chunks. -->
          <!-- Well, yah. It is still possible that we accidentally
          generate a duplicate ID this way but the chance seems very
          limited: one of the original IDs would have to look exactly as my
          generated IDs. -->
         <xsl:value-of select="concat('idg-', translate($self,'\/. ','---_'),'-', count((preceding::*|ancestor::*)[@*[local-name(.) = 'id']]))"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
