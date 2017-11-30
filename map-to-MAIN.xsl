<?xml version="1.0"?>
<!DOCTYPE xsl:stylesheet
[
  <!ENTITY dbns "http://docbook.org/ns/docbook">
]>

<xsl:stylesheet version="1.0" xmlns="http://docbook.org/ns/docbook"
 xmlns:xi="http://www.w3.org/2001/XInclude"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:strip-space elements="*"/>

  <xsl:output method="xml" indent="yes"/>
  <xsl:include href="chunker.xsl"/>

  <xsl:param name="prefix" select="''"/>
  <xsl:param name="entityfile" select="'entities.xml'"/>
  <xsl:param name="replace" select="''"/>
  <xsl:param name="remove" select="''"/>
  <xsl:param name="includes.filename" select="'includes'"/>

  <!-- For chunker.xsl -->
  <xsl:param name="base.dir"/>
  <xsl:param name="chunk.quietly" select="0"/>
  <xsl:param name="chunker.output.media-type" select="''"/>
  <xsl:param name="chunker.output.method" select="'text'"/>

  <xsl:template match="/">
    <!-- Move the xml-stylesheet PI before the DOCTYPE declaration. -->
    <xsl:apply-templates select="node()[normalize-space()][1][self::processing-instruction()]"/>
    <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE </xsl:text>
    <!-- <xsl:value-of select="local-name(/*[1])"/>-->
    <xsl:text>book</xsl:text>
    <xsl:text disable-output-escaping="yes"> [&#10; &lt;!ENTITY % entities SYSTEM "</xsl:text>
    <xsl:value-of select="$entityfile"/>
    <xsl:text disable-output-escaping="yes">"&gt;&#10; %entities;&#10;]&gt;&#10;</xsl:text>
    <xsl:apply-templates/>
    <xsl:call-template name="collect.all.files"/>
  </xsl:template>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Kill whitespace -->
  <xsl:template match="text()[not(normalize-space(.))]">
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="*" priority="0">
    <xsl:message>WARNING: Unhandled element <xsl:value-of select="local-name(.)"/>, ignored.</xsl:message>
  </xsl:template>

  <xsl:template name="collect.all.files">
    <xsl:variable name="files">
      <xsl:apply-templates select="//*/@href" mode="collect.files"/>
    </xsl:variable>
    <xsl:call-template name="write.chunk">
      <xsl:with-param name="filename" select="$includes.filename"/>
      <xsl:with-param name="content" select="$files"/>
      <xsl:with-param name="media-type" select="$chunker.output.media-type"/>
      <xsl:with-param name="method" select="$chunker.output.method"/>
      <xsl:with-param name="encoding" select="$chunker.output.encoding"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Keep the element as is. -->
  <xsl:template match="title">
    <title>
      <xsl:apply-templates/>
    </title>
  </xsl:template>

  <!-- Step over the element. -->
  <xsl:template match="prodinfo|vrmlist|frontmatter|backmatter">
    <xsl:apply-templates/>
  </xsl:template>

  <!-- Ignore the element. -->
  <!-- FIXME: ignoring prodname makes me feel a bit uneasy... -->
  <xsl:template match="bookmeta|bookrights|bookid|series|component|brand|prodname|vrm"/>

  <!-- Any other types of maps necessary? -->
  <xsl:template match="bookmap|map">
    <book>
      <xsl:apply-templates select="@*|node()"/>
    </book>
  </xsl:template>

  <!-- FIXME: mapref is unhandled. -->
  <xsl:template match="mapref">
    <xsl:message>WARNING: mapref element is unhandled. Document will be incomplete.</xsl:message>
  </xsl:template>

  <xsl:template match="*[@href and not(mapref)]">
    <xsl:variable name="filename">
      <xsl:call-template name="mangle-filename">
        <xsl:with-param name="input" select="@href"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:message>Using filename=<xsl:value-of select="$filename"/></xsl:message>
    <xi:include href="{$filename}"/>
  </xsl:template>

  <xsl:template match="bookmeta">
    <info>
      <xsl:apply-templates/>
    </info>
  </xsl:template>

  <!-- The Fujitsu docs use both prodname ("ServerView") and Prognum ("CMM
  V1.3"). Using the one that said CMM seemed more fitting here. And we'll
  have to change that anyway before the conversion. -->
  <xsl:template match="prognum">
    <productname>
      <xsl:apply-templates/>
    </productname>
  </xsl:template>

  <!-- I think I have misunderstood the meaning of the vrm element... -->
  <!-- <xsl:template match="vrm">
    <productnumber>
      <xsl:value-of select="@version"/>
    </productnumber>
  </xsl:template> -->

  <!-- XIncludes directly in MAIN. -->
  <xsl:template match="@href" mode="collect.files">
    <xsl:variable name="file">
      <xsl:call-template name="mangle-filename">
        <xsl:with-param name="input" select="."/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="removal">
      <xsl:if test="contains($remove, concat(' ', normalize-space(.), ' '))">1</xsl:if>
    </xsl:variable>
    <xsl:variable name="replacement">
      <xsl:if test="contains($replace, concat(' ', normalize-space(.), '='))">
        <xsl:value-of select="substring-before(substring-after($replace, concat(' ', normalize-space(.), '=')), ' ')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:message>**** href:
     file=<xsl:value-of select="$file"/>
     removal=<xsl:value-of select="$removal"/>
     replacement=<xsl:value-of select="$replacement"/>
    </xsl:message>

    <xsl:choose>
      <xsl:when test="$removal = 1">
        <xsl:value-of select="concat('file-removal:', .)"/>
      </xsl:when>
      <xsl:when test="not($replacement = '')">
        <xsl:value-of select="concat('source-file-replaced:', $replacement)"/>
        <xsl:choose>
          <xsl:when test="ancestor::*[@href]">
            <xsl:variable name="parentfile">
              <xsl:call-template name="mangle-filename">
                <xsl:with-param name="input" select="ancestor::*[1]/@href"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:value-of
             select="concat('append-to:', $parentfile, ',generate-include:', $replacement)"
            />
          </xsl:when>
          <xsl:otherwise>
            <xi:include href="{$replacement}"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat('source-file:', ., '&#10;')"/>
        <xsl:if test="ancestor::*[@href]">
          <xsl:variable name="parentfile">
            <xsl:call-template name="mangle-filename">
              <xsl:with-param name="input" select="ancestor::*[1]/@href"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:value-of
           select="concat('append-to:', $parentfile, ',generate-include:', $file)"/>
        </xsl:if>
        <xsl:call-template name="changeroot">
          <xsl:with-param name="file" select="$file"/>
        </xsl:call-template>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template name="mangle-filename">
    <xsl:param name="input" select="'NOINPUT'"/>
    <xsl:value-of select="concat($prefix, '-', translate($input, '/,_ ', '---'))"/>
  </xsl:template>

  <xsl:template name="changeroot">
    <xsl:param name="file" select="'NOINPUT'"/>
    <xsl:param name="node" select="."/>
    <xsl:variable name="root">
      <xsl:choose>
        <xsl:when
          test="local-name($node) = 'preface' or
                local-name($node) = 'appendix' or
                local-name($node) = 'chapter'">
          <xsl:value-of select="local-name($node)"/>
        </xsl:when>
        <xsl:when test="local-name($node) = 'topicref'">
          <xsl:text>section</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message>WARNING: Unhandled element <xsl:value-of select="local-name(.)"/> (with @href), replaced with section.</xsl:message>
          <xsl:text>section</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="concat('file:', $file, ',root:', $root)"/>
  </xsl:template>

</xsl:stylesheet>
