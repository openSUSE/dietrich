<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

 <xsl:output method="text"/>
 <xsl:strip-space elements="*"/>

 <xsl:template match="/map">
  <xsl:text disable-output-escaping="no">&lt;!--
  Keyword to entity file
-->&#10;</xsl:text>
  <xsl:apply-templates/>
 </xsl:template>

 <!-- Ignore these elements -->
 <xsl:template match="title"/>
 <xsl:template match="keydef[@type='concept']"/>

 <xsl:template match="keydef">
  <xsl:variable name="key">
   <xsl:choose>
    <xsl:when test="contains(@keys, ' ')">
     <!-- FIXME -->
     <xsl:value-of select="@keys"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="@keys"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:variable name="content">
   <xsl:variable name="tmp">
    <xsl:apply-templates/>
   </xsl:variable>
   <xsl:text> "</xsl:text>
   <xsl:value-of select="normalize-space($tmp)"/>
   <xsl:text>"</xsl:text>
  </xsl:variable>
  <xsl:text>&lt;!ENTITY </xsl:text>
  <xsl:value-of select="$key"/>
  <xsl:value-of select="$content"/>
  <xsl:text>&gt;&#10;</xsl:text>
 </xsl:template>

 <xsl:template match="tm">
  <xsl:apply-templates/>
  <xsl:choose>
   <xsl:when test="@tmtype='reg'">®</xsl:when>
  </xsl:choose>
  <xsl:text></xsl:text>
 </xsl:template>

</xsl:stylesheet>