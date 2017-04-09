<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <xsl:template name="relpath">
    <xsl:param name="input" select="''"/>
    <xsl:param name="prefix" select="''"/>
    <xsl:variable name="mangled-prefix">
      <xsl:choose>
        <xsl:when test="string-length($prefix) &gt; 0">
          <!-- Need to remove the name of the file here... -->
          <xsl:call-template name="remove-rightmost">
            <xsl:with-param name="input" select="$prefix"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$relativefilepath"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:call-template name="straighten-path">
      <xsl:with-param name="input" select="concat($mangled-prefix, '/', $input)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="abspath">
    <xsl:param name="input" select="''"/>
    <xsl:param name="prefix" select="''"/>
    <xsl:variable name="relpath">
      <xsl:call-template name="relpath">
        <xsl:with-param name="input" select="$input"/>
        <xsl:with-param name="prefix" select="$prefix"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:value-of select="concat('file:', $basepath, '/', $relpath)"/>
  </xsl:template>

  <!-- Code to eliminate ".." from paths. -->
  <!-- This is not strictly necessary for the XIncludes to work but if we
  later want to dedupe this content and create entities from it, it is
  necessary. This is the XSLT implementation of (basically) looping over the
  sed expression s_[^/]+/..__g ... Hella concise tho. -->
  <xsl:template name="straighten-path">
    <xsl:param name="input" select="'/path/..'"/>

    <xsl:variable name="start" select="substring-before($input,'/..')"/>
    <xsl:variable name="trimmed-start">
      <xsl:call-template name="remove-rightmost">
        <xsl:with-param name="input" select="$start"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="end">
     <xsl:choose>
       <xsl:when test="(string-length($trimmed-start) = 0 and not(starts-with($input,'/')))
                       or string-length(translate($trimmed-start, '/', '')) = 0">
         <xsl:value-of select="substring-after($input,'/../')"/>
       </xsl:when>
       <xsl:otherwise>
         <xsl:value-of select="substring-after($input,'/..')"/>
       </xsl:otherwise>
     </xsl:choose>
    </xsl:variable>
    <xsl:variable name="output-candidate" select="concat($trimmed-start, $end)"/>

    <xsl:choose>
      <xsl:when test="contains($output-candidate, '/..')">
        <xsl:call-template name="straighten-path">
          <xsl:with-param name="input" select="$output-candidate"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="string-length($output-candidate) &gt; 0">
        <xsl:value-of select="$output-candidate"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$input"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <xsl:template name="remove-rightmost">
    <xsl:param name="input" select="'/path'"/>
    <xsl:param name="handled" select="''"/>
    <xsl:variable name="to-handle" select="substring($input, string-length($handled) + 1)"/>
    <xsl:variable name="this-segment">
      <xsl:value-of select="substring-before($to-handle, '/')"/>
    </xsl:variable>
    <xsl:variable name="next-segments">
      <xsl:value-of select="substring-after($to-handle, '/')"/>
    </xsl:variable>

    <xsl:choose>
      <xsl:when test="not(contains($input, '/'))"/> <!-- No op, can be thrown away. -->
      <xsl:when test="contains($next-segments, '/')">
        <xsl:call-template name="remove-rightmost">
          <xsl:with-param name="input" select="$input"/>
          <xsl:with-param name="handled" select="concat($handled, $this-segment, '/')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="slash">
          <xsl:if test="starts-with($to-handle, '/')">/</xsl:if>
        </xsl:variable>
        <xsl:value-of select="concat($handled, $this-segment, $slash)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
