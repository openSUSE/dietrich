<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
 xmlns:d="http://docbook.org/ns/docbook"
 xmlns:py="urn:x-suse:python:dietrich"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="d">
 
 <xsl:template match="d:article">
  <art>
   <xsl:apply-templates/>
  </art>
 </xsl:template>

 <xsl:template match="d:para">
  <p>
   <xsl:apply-templates/>
  </p>
 </xsl:template>
 
 <xsl:template match="d:envar">
  <ph><xsl:value-of select="py:normpath(text())"/></ph>
 </xsl:template>
 
</xsl:stylesheet>