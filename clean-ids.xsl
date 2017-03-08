<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <xsl:param name="linkends" select="''"/>

  <xsl:template match="/">
    <!-- Move the xml-stylesheet PI before the DOCTYPE declaration. -->
    <xsl:apply-templates select="node()[normalize-space()][1][self::processing-instruction()]"/>
    <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE </xsl:text>
    <xsl:value-of select="local-name(/*[1])"/>
    <xsl:text disable-output-escaping="yes"> PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"</xsl:text>
    <xsl:text disable-output-escaping="yes"> [ &lt;!ENTITY % entities SYSTEM "entities.ent"&gt; %entities; ]&gt;</xsl:text>
    <xsl:apply-templates select="@*|node()[not(self::node()[normalize-space()][1][self::processing-instruction()])]"/>
  </xsl:template>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- We get a list of linkends, all IDs that are not part of that list are
  removed here. -->
  <xsl:template match="@id">
    <xsl:if test="contains($linkends, concat(' ', self::node(), ' '))">
      <xsl:attribute name="id"><xsl:apply-templates/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- Does not really fit here, but ... oh well: Create an entity definition
  from those weird converted conrefs. -->
  <xsl:template match="inlinemediaobject[@remap='ph']">
    <xsl:message>replaced-with-entity:<xsl:value-of select="imageobject/imagedata/@fileref"/></xsl:message>
    <xsl:text>⁂</xsl:text>
    <xsl:value-of select="translate(substring-after(imageobject/imagedata/@fileref, '#'), '/._', '')"/>
    <xsl:text>;</xsl:text>
  </xsl:template>
</xsl:stylesheet>
