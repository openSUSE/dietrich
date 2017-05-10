<!DOCTYPE xsl:stylesheet
[

 <!ENTITY dbblocks "address|bibliolist|blockquote|bridgehead|calloutlist|caution|classsynopsis|cmdsynopsis|constraintdef|constructorsynopsis|destructorsynopsis|epigraph|equation|example|fieldsynopsis|figure|funcsynopsis|glosslist|important|informalexample|informalfigure|informaltable|itemizedlist|literallayout|mediaobject|methodsynopsis|msgset|note|orderedlist|procedure|procedure|productionset|programlisting|programlistingco|qandaset|revhistory|screen|screenco|screenshot|segmentedlist|sidebar|simplelist|synopsis|table|task|tip|variablelist|warning">
 <!ENTITY dbselfblocks "self::address|self::bibliolist|self::blockquote|self::bridgehead|self::calloutlist|self::caution|self::classsynopsis|self::cmdsynopsis|self::constraintdef|self::constructorsynopsis|self::destructorsynopsis|self::epigraph|self::equation|self::example|self::fieldsynopsis|self::figure|self::funcsynopsis|self::glosslist|self::important|self::informalexample|self::informalfigure|self::informaltable|self::itemizedlist|self::literallayout|self::mediaobject|self::methodsynopsis|self::msgset|self::note|self::orderedlist|self::procedure|self::procedure|self::productionset|self::programlisting|self::programlistingco|self::qandaset|self::revhistory|self::screen|self::screenco|self::screenshot|self::segmentedlist|self::sidebar|self::simplelist|self::synopsis|self::table|self::task|self::tip|self::variablelist|self::warning">
 <!ENTITY dbblocksinpara "para/address|para/bibliolist|para/blockquote|para/bridgehead|para/calloutlist|para/caution|para/classsynopsis|para/cmdsynopsis|para/constraintdef|para/constructorsynopsis|para/destructorsynopsis|para/epigraph|para/equation|para/example|para/fieldsynopsis|para/figure|para/funcsynopsis|para/glosslist|para/important|para/informalexample|para/informalfigure|para/informaltable|para/itemizedlist|para/literallayout|para/mediaobject|para/methodsynopsis|para/msgset|para/note|para/orderedlist|para/procedure|para/procedure|para/productionset|para/programlisting|para/programlistingco|para/qandaset|para/revhistory|para/screen|para/screenco|para/screenshot|para/segmentedlist|para/sidebar|para/simplelist|para/synopsis|para/table|para/task|para/tip|para/variablelist|para/warning">

]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>

  <!-- Stuff like para/informaltable does not go over well with the NovDoc
  stylesheets, so properly convert those things beforehand. -->

  <!-- Stolen from http://doccookbook.sourceforge.net/html/en/dbc.structure.move-blocks-in-para.html ,
  therefore those long entities above use the DocBook-5 names of elements...
  FIXME. -->

  <xsl:strip-space elements="para"/>
  <xsl:preserve-space elements="screen programlisting literallayout"/>
  <xsl:output indent="yes"/>

  <xsl:template match="node() | @*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template> 

  <xsl:template match="para" priority="1">
    <xsl:apply-templates select="node()[1]"/>
  </xsl:template>

  <xsl:template match="&dbblocksinpara;" priority="1">
    <xsl:copy-of select="."/>
    <xsl:text>&#10;</xsl:text>
    <xsl:apply-templates select="following-sibling::node()[1]"/>
  </xsl:template>

  <xsl:template match="para/*|para/text()" priority="0">
    <xsl:element name="{local-name(..)}">
      <xsl:apply-templates select="." mode="copy"/>
    </xsl:element>
    <xsl:text>&#10;</xsl:text>
    <xsl:apply-templates
      select="following-sibling::*[&dbselfblocks;][1]"/>
  </xsl:template>

  <xsl:template match="para/*|para/text()" mode="copy">
    <xsl:copy-of select="."/>
    <xsl:if test="not(following-sibling::node()[1][&dbselfblocks;])">
      <xsl:apply-templates select="following-sibling::node()[1]"
        mode="copy"/>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
