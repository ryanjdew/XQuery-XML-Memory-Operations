<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xdmp="http://marklogic.com/xdmp" xmlns:mem-op="http://maxdewpoint.blogspot.com/memory-operations" xmlns:map="http://marklogic.com/xdmp/map" extension-element-prefixes="xdmp" exclude-result-prefixes="mem-op xdmp map" version="2.0">
  <xdmp:import-module namespace="http://maxdewpoint.blogspot.com/memory-operations" href="memory-operations.xqy" />
  <xsl:param name="transaction-map" as="map:map" />
  <xsl:variable name="nodes-to-modify" select="map:get($transaction-map, 'nodes-to-modify')" />
  <xsl:variable name="operations" select="map:get($transaction-map, 'modifier-nodes')" />
  <xsl:template match="/">
    <xsl:apply-templates select="node()|@*" />
  </xsl:template>
  <xsl:template match="node()|@*">
    <xsl:choose>
      <xsl:when test="some $n in $nodes-to-modify satisfies $n is .">
        <xsl:variable name="id-qn" select="mem-op:generate-id-qn(.)" />
        <xsl:variable name="operations" select="$operations[*[node-name(.) eq $id-qn]]" />
        <xsl:variable name="operation-names" select="distinct-values($operations/@mem-op:operation)" />
        <xsl:variable name="replace-node" select="$operations[@mem-op:operation = 'replace']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
        <xsl:variable name="node-name" select="($replace-node/node-name(.), ($operations[@mem-op:operation = 'rename']/*[empty(self::mem-op:*)])[1]/node-name(.), node-name(.))[1]" />
        <xsl:apply-templates select="$operations[@mem-op:operation = 'insert-before']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
        <xsl:choose>
          <xsl:when test=". instance of attribute()">
            <xsl:attribute name="{$node-name}">
              <xsl:choose>
                <xsl:when test="$operation-names = 'replace-value'">
                  <xsl:value-of select="$operations[@mem-op:operation = 'replace-value']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
                </xsl:when>
                <xsl:when test="$operation-names = 'replace'">
                  <xsl:value-of select="$replace-node" />
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="." />
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="transform">
              <xsl:with-param name="content-to-transform">
                <xsl:choose>
                  <xsl:when test="$operation-names = 'replace' and empty($replace-node)">
                  </xsl:when>
                  <xsl:when test="$operation-names = 'replace' and count($replace-node) gt 1">
                    <xsl:copy-of select="$replace-node" />
                  </xsl:when>
                  <xsl:when test=". instance of element()">
                    <xsl:element name="{$node-name}">
                      <xsl:choose>
                        <xsl:when test="$operation-names = 'replace-value'">
                          <xsl:value-of select="$operations[@mem-op:operation = 'replace-value']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:copy-of select="$operations[@mem-op:operation = 'insert-child-first']/(@node()[empty(self::attribute(mem-op:operation))])" />
                          <xsl:choose>
                            <xsl:when test="$operation-names = 'replace'">
                              <xsl:copy-of select="$replace-node/@*" />
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:apply-templates select="@*" />
                            </xsl:otherwise>
                          </xsl:choose>
                          <xsl:copy-of select="$operations[@mem-op:operation = ('insert-child-last', 'insert-child')]/(@node()[empty(self::attribute(mem-op:operation))])" />
                          <xsl:copy-of select="$operations[@mem-op:operation = 'insert-child-first']/(node()[empty(self::mem-op:*)])" />
                          <xsl:choose>
                            <xsl:when test="$operation-names = 'replace'">
                              <xsl:copy-of select="$replace-node/node()" />
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:apply-templates select="node()" />
                            </xsl:otherwise>
                          </xsl:choose>
                          <xsl:copy-of select="$operations[@mem-op:operation = ('insert-child-last', 'insert-child')]/(node()[empty(self::mem-op:*)])" />
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:element>
                  </xsl:when>
                  <xsl:when test=". instance of processing-instruction()">
                    <xsl:processing-instruction name="{$node-name}">
                      <xsl:choose>
                        <xsl:when test="$operation-names = 'replace-value'">
                          <xsl:value-of select="$operations[@mem-op:operation = 'replace-value']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
                        </xsl:when>
                        <xsl:when test="$operation-names = 'replace'">
                          <xsl:value-of select="$replace-node" />
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:value-of select="." />
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:processing-instruction>
                  </xsl:when>
                  <xsl:when test=". instance of comment()">
                    <xsl:comment>
                      <xsl:choose>
                        <xsl:when test="$operation-names = 'replace-value'">
                          <xsl:value-of select="$operations[@mem-op:operation = 'replace-value']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
                        </xsl:when>
                        <xsl:when test="$operation-names = 'replace'">
                          <xsl:value-of select="$replace-node" />
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:value-of select="." />
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:comment>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:copy>
                      <xsl:choose>
                        <xsl:when test="$operation-names = 'replace-value'">
                          <xsl:value-of select="$operations[@mem-op:operation = 'replace-value']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:copy-of select="$operations[@mem-op:operation = 'insert-child-first']/(@node()[empty(self::attribute(mem-op:operation))])" />
                          <xsl:choose>
                            <xsl:when test="$operation-names = 'replace'">
                              <xsl:copy-of select="$replace-node/@*" />
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:apply-templates select="@*" />
                            </xsl:otherwise>
                          </xsl:choose>
                          <xsl:copy-of select="$operations[@mem-op:operation = ('insert-child-last', 'insert-child')]/(@node()[empty(self::attribute(mem-op:operation))])" />
                          <xsl:copy-of select="$operations[@mem-op:operation = 'insert-child-first']/(node()[empty(self::mem-op:*)])" />
                          <xsl:choose>
                            <xsl:when test="$operation-names = 'replace'">
                              <xsl:copy-of select="$replace-node/node()" />
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:apply-templates select="node()" />
                            </xsl:otherwise>
                          </xsl:choose>
                          <xsl:copy-of select="$operations[@mem-op:operation = ('insert-child-last', 'insert-child')]/(node()[empty(self::mem-op:*)])" />
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:copy>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:with-param>
              <xsl:with-param name="transform-operations">
                <xsl:copy-of select="$operations[@mem-op:operation = 'transform']/node()[empty(self::mem-op:*)]" />
              </xsl:with-param>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:copy-of select="$operations[@mem-op:operation = 'insert-after']/(@node()[empty(self::attribute(mem-op:operation))]|node()[empty(self::mem-op:*)])" />
      </xsl:when>
      <xsl:when test=". instance of element()">
        <xsl:element name="{name()}">
          <xsl:apply-templates select="@*" />
          <xsl:apply-templates/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="node()|@*" />
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="transform">
    <xsl:param name="content-to-transform" />
    <xsl:param name="transform-operations" />
    <xsl:choose>
      <xsl:when test="exists($transform-operations[. ne ''])">
        <xsl:copy-of select="mem-op:run-transform($transaction-map, $transform-operations[1], $content-to-transform)" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="$content-to-transform" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
