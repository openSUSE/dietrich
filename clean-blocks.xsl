<!DOCTYPE xsl:stylesheet
[
 <!ENTITY dbns "http://docbook.org/ns/docbook">
 <!ENTITY dbblocks "d:address|d:bibliolist|d:blockquote|d:bridgehead|d:calloutlist|d:caution|d:classsynopsis|d:cmdsynopsis|d:constraintdef|d:constructorsynopsis|d:destructorsynopsis|d:epigraph|d:equation|d:example|d:fieldsynopsis|d:figure|d:funcsynopsis|d:glosslist|d:important|d:informalexample|d:informalfigure|d:informaltable|d:itemizedlist|d:literallayout|d:mediaobject|d:methodsynopsis|d:msgset|d:note|d:orderedlist|d:procedure|d:procedure|d:productionset|d:programlisting|d:programlistingco|d:qandaset|d:revhistory|d:screen|d:screenco|d:screenshot|d:segmentedlist|d:sidebar|d:simplelist|d:synopsis|d:table|d:task|d:tip|d:variablelist|d:warning">
 <!ENTITY dbselfblocks "self::d:address|d:self::bibliolist|d:self::blockquote|d:self::bridgehead|d:self::calloutlist|d:self::caution|d:self::classsynopsis|d:self::cmdsynopsis|d:self::constraintdef|d:self::constructorsynopsis|d:self::destructorsynopsis|d:self::epigraph|d:self::equation|d:self::example|d:self::fieldsynopsis|d:self::figure|d:self::funcsynopsis|d:self::glosslist|d:self::important|d:self::informalexample|d:self::informalfigure|d:self::informaltable|d:self::itemizedlist|d:self::literallayout|d:self::mediaobject|d:self::methodsynopsis|d:self::msgset|d:self::note|d:self::orderedlist|d:self::procedure|d:self::procedure|d:self::productionset|d:self::programlisting|d:self::programlistingco|d:self::qandaset|d:self::revhistory|d:self::screen|d:self::screenco|d:self::screenshot|d:self::segmentedlist|d:self::sidebar|d:self::simplelist|d:self::synopsis|d:self::table|d:self::task|d:self::tip|d:self::variablelist|d:self::warning">
 <!ENTITY dbblocksinpara "d:para/d:address|d:para/d:bibliolist|d:para/d:blockquote|d:para/d:bridgehead|d:para/d:calloutlist|d:para/d:caution|d:para/d:classsynopsis|d:para/d:cmdsynopsis|d:para/d:constraintdef|d:para/d:constructorsynopsis|d:para/d:destructorsynopsis|d:para/d:epigraph|d:para/d:equation|d:para/d:example|d:para/d:fieldsynopsis|d:para/d:figure|d:para/d:funcsynopsis|d:para/d:glosslist|d:para/d:important|d:para/d:informalexample|d:para/d:informalfigure|d:para/d:informaltable|d:para/d:itemizedlist|d:para/d:literallayout|d:para/d:mediaobject|d:para/d:methodsynopsis|d:para/d:msgset|d:para/d:note|d:para/d:orderedlist|d:para/d:procedure|d:para/d:procedure|d:para/d:productionset|d:para/d:programlisting|d:para/d:programlistingco|d:para/d:qandaset|d:para/d:revhistory|d:para/d:screen|d:para/d:screenco|d:para/d:screenshot|d:para/d:segmentedlist|d:para/d:sidebar|d:para/d:simplelist|d:para/d:synopsis|d:para/d:table|d:para/d:task|d:para/d:tip|d:para/d:variablelist|d:para/d:warning">

]>
<xsl:stylesheet version="1.0"
 xmlns="&dbns;"
 xmlns:d="&dbns;"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml"/>

  <!-- Stuff like para/informaltable does not go over well with the NovDoc
  stylesheets, so properly convert those things beforehand. -->

  <!-- Stolen from http://doccookbook.sourceforge.net/html/en/dbc.structure.move-blocks-in-para.html ,
  therefore those long entities above use the DocBook-5 names of elements...
  FIXME. -->

  <xsl:strip-space elements="d:para"/>
  <xsl:preserve-space elements="d:screen d:programlisting d:literallayout"/>
  <xsl:output indent="yes"/>

  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template> 

  <xsl:template match="d:para">
    <xsl:apply-templates select="node()[1]"/>
  </xsl:template>

  <xsl:template match="&dbblocksinpara;">
    <xsl:copy-of select="."/>
    <xsl:text>&#10;</xsl:text>
    <xsl:apply-templates select="following-sibling::node()[1]"/>
  </xsl:template>

  <xsl:template match="d:para/node()">
    <para>
      <xsl:apply-templates select="." mode="copy"/>
    </para>
    <xsl:text>&#10;</xsl:text>
    <xsl:apply-templates
      select="following-sibling::*[&dbselfblocks;][1]"/>
  </xsl:template>

  <xsl:template match="d:para/node()" mode="copy">
    <xsl:copy-of select="."/>
    <xsl:if test="not(following-sibling::node()[1][&dbselfblocks;])">
      <xsl:apply-templates select="following-sibling::node()[1]"
        mode="copy"/>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
