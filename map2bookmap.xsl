<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:exsl="http://exslt.org/common"
 exclude-result-prefixes="exsl">

 <xsl:strip-space elements="*"/>
 <xsl:output indent="yes"/>

 <xsl:template match="*">
  <xsl:message>Unknown element: <xsl:value-of select="local-name()"/></xsl:message>
 </xsl:template>

 <!-- ================================================================== -->
 <!-- Helper functions -->
 <xsl:template name="getdir">
  <xsl:param name="filename" select="''"/>
  <xsl:if test="contains($filename, '/')">
   <xsl:value-of select="substring-before($filename, '/')"/>
   <xsl:text>/</xsl:text>
   <xsl:call-template name="getdir">
    <xsl:with-param name="filename" select="substring-after($filename, '/')"/>
   </xsl:call-template>
  </xsl:if>
 </xsl:template>

 <!-- ================================================================== -->
 <xsl:template match="mapref">
  <xsl:variable name="ditamap.node" select="document(@href)/*"/>

  <xsl:message>Resolve mapref: <xsl:value-of select="@href"/>
  </xsl:message>
  <xsl:apply-templates select="exsl:node-set($ditamap.node)/*"/>
 </xsl:template>

 <xsl:template match="map">
  <bookmap>
   <xsl:if test="@xml:lang">
    <xsl:copy-of select="@xml:lang"/>
   </xsl:if>
   <xsl:apply-templates>
    <xsl:with-param name="first" select="true()"/>
   </xsl:apply-templates>
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
  <xsl:param name="first" select="false()"/>
  <xsl:param name="dir">
   <xsl:call-template name="getdir">
    <xsl:with-param name="filename" select="@href"/>
   </xsl:call-template>
  </xsl:param>

  <xsl:choose>
   <xsl:when test="$first">
    <chapter href="{@href}">
     <xsl:apply-templates>
      <xsl:with-param name="dir" select="$dir"/>
     </xsl:apply-templates>
    </chapter>
   </xsl:when>
   <xsl:otherwise>
    <xsl:apply-templates>
     <xsl:with-param name="dir" select="$dir"/>
    </xsl:apply-templates>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="topicref">
  <xsl:param name="dir"/>

  <topicref href="{@href}" type="concept" format="dita">
   <xsl:apply-templates/>
  </topicref>
 </xsl:template>
</xsl:stylesheet>