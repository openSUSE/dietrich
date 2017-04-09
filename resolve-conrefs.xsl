<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <xsl:include href="paths.xsl"/>

  <xsl:param name="basepath" select="''"/>
  <xsl:param name="relativefilepath" select="''"/>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*[@conref]">
    <xsl:variable name="node" select="."/>
    <xsl:variable name="prefixpath-candidate">
      <!-- Sooo, let's try to check whether there is either an
      preceding::-@CONREF:start comment. Comments stand outside the normal
      XML structure, so I can only use the preceding::/following:: axes. I
      should still be fine however, as long as I make sure to always add an
      @CONREF:end comment. -->
      <!-- FIXME: This handles conrefs wrongly if they are nested and are not
      the first within their "nest." conref:1/[conref/2, conref/3, conref/4] ->
      conref/3 and conref/4 are wrongly empty here. -->
      <!-- Instead, I need to add the relpath#id to the @CONREF:end comments
      too, then I can easily match which one is the first that is still open.
      substring-after($myconrefvalue,' '), preceding this node...?-->
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
    <xsl:variable name="file" select="normalize-space(substring-before(@conref, '#'))"/>
    <xsl:variable name="relpath">
      <xsl:call-template name="relpath">
        <xsl:with-param name="input" select="$file"/>
        <xsl:with-param name="prefix" select="$prefixpath"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="abspath">
      <xsl:call-template name="abspath">
        <xsl:with-param name="input" select="$file"/>
        <xsl:with-param name="prefix" select="$prefixpath"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="id">
      <xsl:value-of select="normalize-space(substring-after(@conref, '#'))"/>
    </xsl:variable>
    <xsl:variable name="relevant-id">
      <!-- FIXME: Not sure how exactly to get this multi-layer id thing
      working in here... -->
      <xsl:call-template name="relevant-id">
        <xsl:with-param name="input" select="$id"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- FIXME: No guarantee that we don't have invalid chars like dash dash
    in these comments. -->
    <xsl:comment>@CONREF:start <xsl:value-of select="concat($relpath, '#', $relevant-id)"/></xsl:comment>
    <xsl:copy-of select="document($abspath)//*[@id = $relevant-id][1]"/>
    <xsl:comment>@CONREF:end </xsl:comment>
  </xsl:template>

  <xsl:template name="relevant-id">
    <xsl:param name="input" select="''"/>
    <xsl:param name="output">
      <xsl:choose>
        <xsl:when test="contains($input,'/')">
          <xsl:call-template name="relevant-id">
            <xsl:with-param name="input" select="substring-after($input, '/')"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$input"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:value-of select="$output"/>
  </xsl:template>

</xsl:stylesheet>
