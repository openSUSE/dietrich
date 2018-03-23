<!DOCTYPE xsl:stylesheet
[
  <!ENTITY dbns "http://docbook.org/ns/docbook">
]>

<xsl:stylesheet version="1.0"
 xmlns="&dbns;"
 xmlns:d="&dbns;"
 xmlns:xi="http://www.w3.org/2001/XInclude"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="d">
  <xsl:output method="xml"/>

  <xsl:include href="paths.xsl"/>

  <xsl:param name="linkends" select="''"/>
  <xsl:param name="root" select="''"/>
  <xsl:param name="includes" select="''"/>
  <xsl:param name="relativefilepath" select="''"/>
  <xsl:param name="tweaks" select="''"/>
  <xsl:param name="entityfile" select="'entities.xml'"/>

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
    <xsl:text disable-output-escaping="yes"> [&#10; &lt;!ENTITY % entities SYSTEM "</xsl:text>
    <xsl:value-of select="$entityfile"/>
    <xsl:text disable-output-escaping="yes">"&gt; %entities;&#10;]&gt;&#10;</xsl:text>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

<!--  <xsl:template match="*[not(/*)]/@*[starts-with(name(self::@*),'xmlns')]"/>-->

  <xsl:template match="/*">
    <xsl:element name="{$actual-root}" namespace="&dbns;">
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
  <!-- I think the <phrase> template from topic2db.xsl is responsible for
  some empty nodes that destroy formatting (i.e. add spaces before periods
  etc.). However, let's not bother with that and do it here. -->
  <xsl:template match="text()[not(normalize-space(.))][following::node()[1][self::comment()[starts-with(.,'@CONREF:')]]]"/>

  <xsl:template name="generate-imports">
    <xsl:param name="input" select="','"/>
    <xsl:variable name="file" select="substring-before($input, ',')"/>
    <xi:include href="{$file}"/>
    <xsl:if test="string-length(substring-after($input, ',')) &gt; 0">
      <xsl:call-template name="generate-imports">
        <xsl:with-param name="input" select="substring-after($input, ',')"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template
    match="@remap|@*[. = '']|@moreinfo[. = 'none']|@inheritnum[. = 'ignore']|
           @float|@continuation[. ='restarts']|d:emphasis/@role[. = 'italic']|@frame"/>

  <!-- We get a list of linkends, all IDs that are not part of that list are
  removed here. If we don't get anything (not even a space), we don't do
  anything. -->
  <xsl:template match="@xml:id">
    <xsl:if test="contains($linkends, concat(' ', self::node(), ' ')) or
                  string-length($linkends) = 0">
      <xsl:attribute name="{name(.)}"><xsl:apply-templates/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- Always remove IDs from phrases, however. Those are just annoying. -->
  <xsl:template match="d:phrase/@xml:id"/>

  <!-- Rewrite paths to images, because DAPS needs images to be in a defined
  place. -->
  <xsl:template match="d:imagedata/@fileref">
    <xsl:param name="mode" select="''"/>
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
    <xsl:choose>
      <xsl:when test="$mode='bare'">
        <xsl:value-of select="$file"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="fileref"><xsl:value-of select="$file"/></xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- <sidebar/> is not so super compatible with our stylesheets:
   * PDF: multi-page sidebars have generally destroyed rendering
   * HTML: sidebar titles are generated wrongly
   => fix the symptom here and generate sections or nothing
  --><!--
  <!-/- nice sections - these have a title. -/->
  <xsl:template match="d:sidebar[d:title]" priority="2">
    <section>
      <xsl:apply-templates select="@*|node()"/>
    </section>
    <xsl:comment>fuckwhat? tpl=1</xsl:comment>
  </xsl:template>

  <!-/- less nice sections - these have a title but it is tagged with an
  <emphasis role=bold> or similar. -/->
  <!-/-  and normalize-space(text()) = '' and  and not(*[2]) -/->
  <xsl:template match="d:sidebar[*[1][ self::d:para and *[1][d:emphasis] ]]"
  priority="1">
    <xsl:variable name="node" select="."/>
    <section>
      <xsl:apply-templates select="@*"/>
      <title><xsl:apply-templates select="*"/></title>
      <xsl:apply-templates select="node()[not($node/*[1])]"/>
    </section>
    <xsl:comment>fuckwhat? tpl=2</xsl:comment>
  </xsl:template>

  <!-/- ugly sections - these don't have a title but might still be needed for
  structural integrity of the document. -/->
  <xsl:template match="d:sidebar" priority="-1">
    <section>
      <xsl:apply-templates select="@*"/>
      <title><!-/- FIXME: Section without title, section structure preserved to keep xml:id -/-></title>
      <xsl:apply-templates select="node()"/>
    </section>
    <xsl:comment>fuckwhat? tpl=3</xsl:comment>
  </xsl:template>

  <xsl:template match="d:literal/d:emphasis">
    <replaceable><xsl:apply-templates/></replaceable>
  </xsl:template>

  <xsl:template match="d:literal/d:phrase">
    <xsl:apply-templates/>
  </xsl:template>-->

  <!-- Fight the weird habit of people putting underline/italic emphases into
  ulinks. -->
  <xsl:template match="d:emphasis[ancestor::d:ulink]">
    <xsl:choose>
      <xsl:when test="contains($tweaks, ' fujitsu ')">
        <!-- FIXME: For reasons unknown to me, adding @*| to the
        apply-templates here makes this fail for some documents. -->
        <xsl:apply-templates select="node()"/>
      </xsl:when>
      <xsl:otherwise>
        <emphasis>
          <xsl:apply-templates select="@*|node()"/>
        </emphasis>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="d:inlinemediaobject[not(ancestor::d:para or ancestor::d:title or ancestor::d:remark or ancestor::d:entry)]">
    <mediaobject><xsl:apply-templates/></mediaobject>
  </xsl:template>

  <xsl:template match="d:imageobject[1]">
    <xsl:variable name="width">
      <xsl:choose>
        <!-- Crudely try to avoid absolute values here. -->
        <!-- FIXME: This does not check for SNAFUs like 100%+ values. -->
        <xsl:when test="contains(d:imagedata[1]/@width, '%')">
          <xsl:value-of select="d:imagedata[1]/@width"/>
        </xsl:when>
        <xsl:otherwise>75%</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="fileref">
      <xsl:apply-templates select="d:imagedata[1]/@fileref">
        <xsl:with-param name="mode" select="'bare'"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="format">
      <!-- FIXME: This only works correctly if we have a three-letter file
      extension. -->
      <xsl:value-of select="translate(substring($fileref, string-length($fileref) - 2), 'abcdefghijklmnoprstuvwxyz', 'ABCDEFGHIJKLMNOPRSTUVWXYZ')"/>
    </xsl:variable>

    <imageobject role="fo">
      <imagedata fileref="{$fileref}" width="{$width}" format="{$format}"/>
    </imageobject>
    <imageobject role="html">
      <imagedata fileref="{$fileref}"/>
    </imageobject>
  </xsl:template>

  <!-- FIXME: I can't handle this shit. (yet) -->
  <xsl:template match="d:imageobject[not(1)]"/>

  <xsl:template match="d:programlisting">
    <screen><xsl:apply-templates/></screen>
  </xsl:template>

  <xsl:template match="d:xref[@linkend='']">
    <citetitle>FIXME: broken external xref</citetitle>
  </xsl:template>

  <!-- Remarks ... this conversion based on the text content is pretty scary. -->
  <xsl:template match="d:emphasis[d:emphasis[@role='bold'][translate(., 'abcdefghijklmnoprstuvwxyz-_+:.?! ', 'ABCDEFGHIJKLMNOPRSTUVWXYZ') = 'PENDING']]">
    <xsl:choose>
      <xsl:when test="contains($tweaks, ' fujitsu ')">
        <xsl:message>WARNING: b/i converted to remark.</xsl:message>
        <remark><xsl:apply-templates select="@*|node()"/></remark>
      </xsl:when>
      <xsl:otherwise>
        <emphasis>
          <xsl:apply-templates select="@*|node()"/>
        </emphasis>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
