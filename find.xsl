<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="text"/>

  <!-- $type: Can be "attribute" or "element" -->
  <xsl:param name="type" select="'attribute'"/>
  <!-- $name: Can be any string -->
  <xsl:param name="name" select="'role'"/>

  <xsl:template match="/">
    <xsl:apply-templates select="@*|*"/>
  </xsl:template>

  <!-- TIL: You can't put $variables in match attributes:
  https://stackoverflow.com/questions/16638529 -->

  <xsl:template match="@*">
    <xsl:if test="$type='attribute' and local-name(.) = $name">
      <xsl:value-of select="."/>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="@*|*"/>
  </xsl:template>

  <xsl:template match="*">
    <xsl:if test="$type='element' and local-name(.) = '$name'">
      <xsl:value-of select="."/>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="@*|*"/>
  </xsl:template>

</xsl:stylesheet>
