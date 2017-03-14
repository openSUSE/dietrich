<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

<xsl:param name="basepath" select="''"/>
<xsl:param name="relativefilepath" select="''"/>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*[@conref]">
    <xsl:variable name="relpath">
      <xsl:call-template name="relpath">
        <xsl:with-param name="input" select="substring-before(@conref, '#')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="abspath">
      <xsl:call-template name="abspath">
        <xsl:with-param name="input" select="substring-before(@conref, '#')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="id">
      <xsl:value-of select="substring-after(@conref, '#')"/>
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
    <!-- FIXME: Multi-level conrefs will not work. -->
    <xsl:comment> START CONREF <xsl:value-of select="concat($relpath, '#', $relevant-id)"/></xsl:comment><xsl:copy-of select="document($abspath)//*[@id = $relevant-id][1]"/><xsl:comment> END CONREF </xsl:comment>
  </xsl:template>

  <xsl:template name="relpath">
    <xsl:param name="input" select="''"/>
    <!-- FIXME: Ideally, we'd cut out the ../ parts here, but this should
    hopefully be fine either way. -->
    <xsl:value-of select="concat($relativefilepath, '/', $input)"/>
  </xsl:template>

  <xsl:template name="abspath">
    <xsl:param name="input" select="''"/>
    <xsl:variable name="relpath">
      <xsl:call-template name="relpath">
        <xsl:with-param name="input" select="$input"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- FIXME: Ideally, we'd cut out the ../ parts here, but this should
    hopefully be fine either way. -->
    <xsl:value-of select="concat('file:', $basepath, '/', $relpath)"/>
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
