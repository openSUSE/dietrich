<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:strip-space elements="*"/>
  <xsl:output indent="yes"/>

 <xsl:template match="*">
  <xsl:message>Unknown element: <xsl:value-of select="local-name()"/></xsl:message>
 </xsl:template>

 <!-- Ignore these elements -->
 <xsl:template match="mapref"/>

 <xsl:template match="map">
  <bookmap>
   <xsl:if test="@xml:lang">
    <xsl:copy-of select="@xml:lang"/>
   </xsl:if>
   <xsl:apply-templates/>
  </bookmap>
 </xsl:template>

 <xsl:template match="topicmeta">
  <bookmeta>
   <!-- FIXME: To be definied... -->
  </bookmeta>
 </xsl:template>

 <xsl:template match="map/title">
  <xsl:copy-of select="."/>
 </xsl:template>
 
 <xsl:template match="map/topicref">
  <chapter href="{@href}">
   <xsl:apply-templates/>
  </chapter>
 </xsl:template>
 
 <xsl:template match="topicref">
  <topicref href="{@href}" type="concept" format="dita">
   <xsl:apply-templates/>
  </topicref>
 </xsl:template>
</xsl:stylesheet>