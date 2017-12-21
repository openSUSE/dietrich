<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0"
 xmlns:exsl="http://exslt.org/common"
 xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="exsl ditaarch">

 <!-- This points to a file, for example HOS-conrefs.xml -->
 <xsl:param name="conrefs.file"/>
 <xsl:variable name="conrefs" select="exsl:node-set(document($conrefs.file, /))"/>

 <xsl:template match="@*|node()" name="copy">
  <xsl:copy>
   <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
 </xsl:template>

 <xsl:template match="*[@conkeyref]">
  <xsl:variable name="preid" select="substring-before(@conkeyref, '/')"/>
  <xsl:variable name="idkey" select="substring-after(@conkeyref, '/')"/>
  <xsl:variable name="node" select="$conrefs//*[@id=$idkey]"/>

  <xsl:choose>
   <!-- We assume filename without .xml is equal to its ID -->
   <xsl:when test="contains($conrefs.file, $preid)">
    <xsl:message>Resolve conkeyref <xsl:value-of
     select="concat($idkey, ' => ', boolean($node))"/></xsl:message>
    <xsl:element name="{local-name(.)}">
     <xsl:apply-templates select="$node"/>
    </xsl:element>
   </xsl:when>
   <xsl:otherwise>
    <!-- We don't know it yet, so... -->
    <xsl:message>Unknown conkeyref ID=<xsl:value-of select="$preid"/> found</xsl:message>
    <xsl:copy-of select="."/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

</xsl:stylesheet>