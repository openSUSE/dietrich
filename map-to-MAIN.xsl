<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <xsl:param name="prefix" select="''"/>

  <xsl:template match="/">
    <!-- Move the xml-stylesheet PI before the DOCTYPE declaration. -->
    <xsl:apply-templates select="node()[normalize-space()][1][self::processing-instruction()]"/>
    <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE </xsl:text>
    <!-- <xsl:value-of select="local-name(/*[1])"/>-->
    <xsl:text>book</xsl:text>
    <xsl:text disable-output-escaping="yes"> PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"</xsl:text>
    <xsl:text disable-output-escaping="yes"> [ &lt;!ENTITY % entities SYSTEM "entities.ent"&gt; %entities; ]&gt;</xsl:text>
    <xsl:apply-templates select="@*|node()"/>
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

  <!-- Keep the element as is. -->
  <xsl:template match="title">
    <xsl:element name="{local-name(.)}">
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- Step over the element. -->
  <xsl:template match="prodinfo|vrmlist|frontmatter|backmatter">
    <xsl:apply-templates/>
  </xsl:template>

  <!-- Ignore the element. -->
  <!-- FIXME: ignoring prodname makes me feel a bit uneasy... -->
  <xsl:template match="bookmeta|bookrights|bookid|series|component|brand|prodname|vrm"/>

  <!-- Any other types of maps necessary? -->
  <xsl:template match="bookmap">
    <book>
      <xsl:apply-templates select="@*|node()"/>
    </book>
  </xsl:template>

  <xsl:template match="@*[local-name(.)='lang']">
    <xsl:attribute name="lang"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="bookmeta">
    <bookinfo>
      <xsl:apply-templates/>
    </bookinfo>
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
  <xsl:template match="*[@href]">
    <xsl:variable name="file">
      <xsl:call-template name="mangle-filename">
       <xsl:with-param name="input" select="@href"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:message>source-file:<xsl:value-of select="@href"/></xsl:message>
    <xi:include href="{$file}" xmlns:xi="http://www.w3.org/2001/XInclude"/>
    <xsl:call-template name="changeroot">
      <xsl:with-param name="file" select="$file"/>
    </xsl:call-template>
    <xsl:apply-templates/>
  </xsl:template>

  <!-- XIncludes that need to be added to different files. -->
  <xsl:template match="*[@href and ancestor::*[@href]]">
    <xsl:variable name="file">
      <xsl:call-template name="mangle-filename">
       <xsl:with-param name="input" select="@href"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="parentfile">
      <xsl:call-template name="mangle-filename">
       <xsl:with-param name="input" select="ancestor::*[1]/@href"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:message>source-file:<xsl:value-of select="@href"/></xsl:message>
    <xsl:message>append-to:<xsl:value-of select="$parentfile"/>,generate-include:<xsl:value-of select="$file"/></xsl:message>
    <xsl:call-template name="changeroot">
      <xsl:with-param name="file" select="$file"/>
    </xsl:call-template>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template name="mangle-filename">
    <xsl:param name="input" select="'NOINPUT'"/>
    <xsl:value-of select="concat($prefix, '-', translate($input,'/,_ ','---'))"/>
  </xsl:template>

  <xsl:template name="changeroot">
    <xsl:param name="file" select="'NOINPUT'"/>
    <xsl:param name="node" select="."/>
    <xsl:variable name="root">
      <xsl:choose>
        <xsl:when
          test="local-name($node) = 'preface' or
                local-name($node) = 'appendix' or
                local-name($node)='chapter'">
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
    <xsl:message>file:<xsl:value-of select="$file"/>,root:<xsl:value-of select="$root"/></xsl:message>
  </xsl:template>

</xsl:stylesheet>
