<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <xsl:include href="paths.xsl"/>

  <xsl:param name="basepath" select="''"/>
  <xsl:param name="relativefilepath" select="''"/>

  <!-- Since comments are not really part of the document structure, I have to
  keep track of how many levels of conrefs there were before manually. -->
  <xsl:variable name="parent-level">
    <xsl:choose>
    <xsl:when test="//comment()[starts-with(., '@CONREF:')]">
      <!-- Since all unresolved conrefs have the same level we can just find
      out what level the first one is. -->
      <xsl:value-of select="substring-before(substring-after(//*[@conref]/preceding::comment()[starts-with(., '@CONREF:start')][1], '@CONREF:start,level-'),' ')"/>
    </xsl:when>
    <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="level" select="$parent-level + 1"/>


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
      <xsl:if test="preceding::comment()[starts-with(., '@CONREF:')][1][starts-with(., concat('@CONREF:start,level-', $parent-level))]">
        <xsl:value-of select="substring-after(preceding::comment()[starts-with(., '@CONREF:start')][1], ' ')"/>
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
    <xsl:comment>
      <xsl:text>@CONREF:start,level-</xsl:text>
      <xsl:value-of select="$level"/><xsl:text> </xsl:text>
      <xsl:value-of select="concat($relpath, '#', $relevant-id)"/>
    </xsl:comment>
    <xsl:copy-of select="document($abspath)//*[@id = $relevant-id][1]"/>
    <xsl:comment>@CONREF:end,level-<xsl:value-of select="$level"/> </xsl:comment>
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
