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

  <!-- Let's not kill remap yet, it can be helpful. -->
  <!-- <xsl:template match="@remap"/> -->

  <!-- We get a list of linkends, all IDs that are not part of that list are
  removed here. -->
  <xsl:template match="@id">
    <xsl:if test="contains($linkends, concat(' ', self::node(), ' '))">
      <xsl:attribute name="id"><xsl:apply-templates/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- Does not really fit here, but ... oh well: Create an entity definition
  from those weird converted conrefs. -->
  <xsl:template match="inlinemediaobject[contains(imageobject/imagedata/@fileref, '.xml#')]|mediaobject[contains(imageobject/imagedata/@fileref, '.xml#')]" priority="10">
    <xsl:variable name="entity" select="translate(substring-after(imageobject/imagedata/@fileref, '.xml#'), '/\ ,;@&amp;', '-')"/>
    <xsl:message>need-entity:<xsl:value-of select="$entity"/>,<xsl:value-of select="imageobject/imagedata/@fileref"/></xsl:message>
    <xsl:text disable-output-escaping="yes">&amp;</xsl:text>
    <xsl:value-of select="$entity"/>
    <xsl:text>;</xsl:text>
  </xsl:template>

  <!-- Any filerefs that are left now should always be valid because the
  idiotic conref conversions are already excluded at this point. -->
  <xsl:template match="imagedata/@fileref">
    <xsl:variable name="file-candidate">
      <xsl:call-template name="cut-off-dirs">
        <xsl:with-param name="input" select="."/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="file" select="translate($file-candidate, '/\ ,;@&amp;', '-')"/>
    <xsl:message>need-image:<xsl:value-of select="$file"/>,<xsl:value-of select="."/></xsl:message>
    <xsl:attribute name="fileref"><xsl:value-of select="$file"/></xsl:attribute>
  </xsl:template>

  <xsl:template name="cut-off-dirs">
    <xsl:param name="input" select="''"/>
    <xsl:param name="output" select="substring-after($input,'../')"/>
    <xsl:choose>
      <xsl:when test="starts-with($output, '../')">
        <xsl:call-template name="cut-off-dirs">
          <xsl:with-param name="input" select="$output"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$output"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="literal/emphasis">
    <replaceable><xsl:apply-templates/></replaceable>
  </xsl:template>

  <xsl:template match="inlinemediaobject[not(ancestor::para or ancestor::title or ancestor::remark or ancestor::entry)]">
    <mediaobject><xsl:apply-templates/></mediaobject>
  </xsl:template>

</xsl:stylesheet>
