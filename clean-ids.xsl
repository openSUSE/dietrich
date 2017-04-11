<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <xsl:include href="paths.xsl"/>

  <xsl:param name="linkends" select="''"/>
  <xsl:param name="root" select="''"/>
  <xsl:param name="includes" select="''"/>
  <xsl:param name="relativefilepath" select="''"/>

  <xsl:variable name="actual-root">
    <xsl:choose>
      <xsl:when test="string-length($root) &gt; 0">
        <xsl:value-of select="$root"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="local-name(/*[1])"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:template match="/">
    <!-- Move the xml-stylesheet PI before the DOCTYPE declaration. -->
    <xsl:apply-templates select="node()[normalize-space()][1][self::processing-instruction()]"/>
    <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE </xsl:text>
    <xsl:value-of select="$actual-root"/>
    <xsl:text disable-output-escaping="yes"> PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"</xsl:text>
    <xsl:text disable-output-escaping="yes"> [ &lt;!ENTITY % entities SYSTEM "entities.ent"&gt; %entities; ]&gt;</xsl:text>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/*">
    <xsl:element name="{$actual-root}">
      <xsl:apply-templates select="@*|node()"/>
      <xsl:if test="string-length($includes) &gt; 0">
        <xsl:call-template name="generate-imports">
          <xsl:with-param name="input" select="$includes"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:element>
  </xsl:template>

  <!-- These comments tend to introduce spaces before punctuation when
  xmlformat is run over them, so remove them. -->
  <xsl:template match="comment()[starts-with(.,'@CONREF:')]"/>

  <xsl:template name="generate-imports">
    <xsl:param name="input" select="','"/>
    <xsl:variable name="file" select="substring-before($input, ',')"/>
    <xi:include href="{$file}" xmlns:xi="http://www.w3.org/2001/XInclude"/>
    <xsl:if test="string-length(substring-after($input, ',')) &gt; 0">
      <xsl:call-template name="generate-imports">
        <xsl:with-param name="input" select="substring-after($input, ',')"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template
    match="@remap|@*[. = '']|@moreinfo[. = 'none']|@inheritnum[. = 'ignore']|
           @float|@continuation[. ='restarts']|emphasis/@role[. = 'italic']"/>

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
    <xsl:variable name="prefixpath-candidate">
      <!-- Sooo, let's try to check whether there is either an
      preceding::-@CONREF:start comment. Comments stand outside the normal
      XML structure, so I can only use the preceding::/following:: axes. I
      should still be fine however, as long as I make sure to always add an
      @CONREF:end comment. -->
      <xsl:if test="preceding::comment()[starts-with(., '@CONREF:')][1][starts-with(., '@CONREF:start ')]">
        <xsl:value-of select="substring-after(preceding::comment()[starts-with(., '@CONREF:start ')][1], '@CONREF:start ')"/>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="prefixpath">
      <xsl:choose>
        <xsl:when test="contains($prefixpath-candidate,'#')">
          <xsl:value-of select="substring-before($prefixpath-candidate,'#')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$prefixpath-candidate"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="relpath">
      <xsl:call-template name="relpath">
        <xsl:with-param name="input" select="normalize-space(.)"/>
        <xsl:with-param name="prefix" select="$prefixpath"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="file" select="translate($relpath, '/\ ,;@&amp;', '-')"/>
    <xsl:message>need-image:<xsl:value-of select="$file"/>,<xsl:value-of select="$relpath"/></xsl:message>
    <xsl:attribute name="fileref"><xsl:value-of select="$file"/></xsl:attribute>
  </xsl:template>

  <!-- <sidebar/> is not so super compatible with our stylesheets:
   * PDF: multi-page sidebars have generally destroyed rendering
   * HTML: sidebar titles are generated wrongly
   => fix the symptom here and just generate bridgeheads
  -->
  <xsl:template match="sidebar">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="sidebar/title">
    <bridgehead renderas="sect4"><xsl:apply-templates/></bridgehead>
  </xsl:template>

  <xsl:template match="literal/emphasis">
    <replaceable><xsl:apply-templates/></replaceable>
  </xsl:template>

  <xsl:template match="literal/phrase">
    <xsl:apply-templates/>
  </xsl:template>

  <!-- Fight the weird habit of people putting underline/italic emphases into
  ulinks.
  FIXME: removing all those italic emphases might be a bit of an overreach...
  -->
  <xsl:template match="emphasis[@role='underline'][ancestor::ulink]|emphasis[@role='italic'][ancestor::ulink]">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="inlinemediaobject[not(ancestor::para or ancestor::title or ancestor::remark or ancestor::entry)]">
    <mediaobject><xsl:apply-templates/></mediaobject>
  </xsl:template>

  <xsl:template match="programlisting">
    <screen><xsl:apply-templates/></screen>
  </xsl:template>

  <xsl:template match="xref[@linkend='']">
    <citetitle>FIXME: broken external xref</citetitle>
  </xsl:template>

  <!-- The concept of remarks appears to be unknown... this is really only
  for Fujitsu docs. Bit scary to have this in here. -->
  <xsl:template match="emphasis[emphasis[@role='bold'][translate(., 'abcdefghijklmnoprstuvwxyz-_+:.?! ', 'ABCDEFGHIJKLMNOPRSTUVWXYZ') = 'PENDING']]">
   <xsl:message>WARNING: b/i converted to remark.</xsl:message>
   <remark><xsl:apply-templates/></remark>
  </xsl:template>

</xsl:stylesheet>
