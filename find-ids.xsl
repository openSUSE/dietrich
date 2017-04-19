<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="text"/>

  <xsl:template match="@*|node()" priority="-1">
      <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="@id|@xml:id">
    <xsl:value-of select="."/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

</xsl:stylesheet>
