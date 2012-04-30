xquery version "3.0";
(:~
Copyright (c) 2012 Ryan Dew

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

@author Ryan Dew (ryan.j.dew@gmail.com)
@version 0.3.3
@description This is a module with function changing XML in memory by creating subtrees using the ancestor, preceding-sibling, and following-sibling axes
				and intersect/except expressions.
:)

module namespace mem-op = "http://maxdewpoint.blogspot.com/memory-operations";
declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare variable $start-mod-qname := QName("","start-modifiers");
declare variable $end-mod-qname := QName("","end-modifiers");

(:
This will accept a seqeunce matching the following pattern
($operation as xs:string,$nodes-to-modify as node()*, fn:QName("","start-modifiers"),$modifier-nodes as node()*, fn:QName("","end-modifiers")
This allows for the processing of multiple expressions at the same time.
Available operations are "replace","insert-child", "insert-child-first","insert-before","insert-after"
To delete, just replace with no modifier nodes
:)

declare function mem-op:advanced-operation(
    $operation-expression as item()*
) as node()?
{
	let $start-modifier-indexes := index-of($operation-expression,$start-mod-qname),
		$end-modifier-indexes := index-of($operation-expression,$end-mod-qname),
		$formatted-items := for $op at $pos in $operation-expression
							where $op instance of xs:string
							return
								let $cur-modifiers-start := ($start-modifier-indexes[. gt $pos])[1],
									$cur-modifiers-end := ($end-modifier-indexes[. gt $pos])[1],
									$modifier-nodes := subsequence($operation-expression, $cur-modifiers-start + 1, $cur-modifiers-end - $cur-modifiers-start - 1),
									$modifier-attributes := $modifier-nodes[self::attribute()],
									$modified-nodes := subsequence($operation-expression,$pos + 1, $cur-modifiers-start - $pos - 1),
									$modified-node-ids := for $mn in $modified-nodes return element mem-op:id {mem-op:generate-id($mn)}
								return (
									element mem-op:operation {
										attribute operation {$op},
										$modified-node-ids
									},
									$modified-nodes,
									element mem-op:modifier-nodes {
										$modifier-attributes,
										$modified-node-ids,
										$modifier-nodes except $modifier-attributes
									}
								),
		$operation-nodes := $formatted-items[self::element(mem-op:operation)],
		$modifier-nodes := $formatted-items[self::element(mem-op:modifier-nodes)]
	return mem-op:process($formatted-items except ($operation-nodes,$modifier-nodes),$modifier-nodes,$operation-nodes)
};

(:
Insert a child into the node
:)
declare function mem-op:insert-child(
    $parent-node as element()+,
    $new-nodes as node()*
) as node()?
{
    mem-op:process($parent-node, $new-nodes, "insert-child")
};

(:
Insert as first child into the node
:)
declare function mem-op:insert-child-first(
    $parent-node as element()+,
    $new-nodes as node()*
) as node()?
{
    mem-op:process($parent-node, $new-nodes, "insert-child-first")
};

(:
Insert a sibling before the node
:)

declare function mem-op:insert-before(
    $sibling as node()+,
    $new-nodes as node()*
) as node()
{
    mem-op:process($sibling, $new-nodes, "insert-before")
};

(:
Insert a sibling after the node
:)
declare function mem-op:insert-after(
    $sibling as node()+,
    $new-nodes as node()*
) as node()
{
    mem-op:process($sibling, $new-nodes, "insert-after")
};

(:
Replace the node
:)
declare function mem-op:replace(
    $replace-nodes as node()+,
    $new-nodes as node()*
) as node()
{
    mem-op:process($replace-nodes except $replace-nodes/descendant::node(), $new-nodes, "replace")
};

(:
Delete the node
:)
declare function mem-op:delete(
    $delete-nodes as node()+
) as node()?
{
    mem-op:process($delete-nodes except $delete-nodes/descendant::node(), (), "replace")
};

(:
New congruent opperations allow you to preform operations on multiple items at sametime.
The new node congruent to the modifer node will used for the operation.

for example you could do:
mem-op:congruent-replace(($article/@xml:lang,$article/title),(attribute xml:lang {"deu"},element title {"Mein Neuer Titel"}))
:)

(:
Insert a child into the node
:)
declare function mem-op:congruent-insert-child(
    $parent-node as element()+,
    $new-nodes as node()*
) as node()?
{
    mem-op:advanced-operation(
		for $n at $pos in $parent-node
		return (
			"insert-child",
			$n,
			$start-mod-qname,
			$new-nodes[$pos],
			$end-mod-qname
		)
	)
};

(:
Insert a child into the node
:)
declare function mem-op:congruent-insert-child-first(
    $parent-node as element()+,
    $new-nodes as node()*
) as node()?
{
    mem-op:advanced-operation(
		for $n at $pos in $parent-node
		return (
			"insert-child-first",
			$n,
			$start-mod-qname,
			$new-nodes[$pos],
			$end-mod-qname
		)
	)
};

(:
Insert a sibling before the node
:)

declare function mem-op:congruent-insert-before(
    $sibling as node()+,
    $new-nodes as node()*
) as node()
{
    mem-op:advanced-operation(
		for $n at $pos in $sibling
		return (
			"insert-before",
			$n,
			$start-mod-qname,
			$new-nodes[$pos],
			$end-mod-qname
		)
	)
};

(:
Insert a sibling after the node
:)
declare function mem-op:congruent-insert-after(
    $sibling as node()+,
    $new-nodes as node()*
) as node()
{
    mem-op:advanced-operation(
		for $n at $pos in $sibling
		return (
			"insert-after",
			$n,
			$start-mod-qname,
			$new-nodes[$pos],
			$end-mod-qname
		)
	)
};

(:
Replace the node
:)
declare function mem-op:congruent-replace(
    $replace-nodes as node()+,
    $new-nodes as node()*
) as node()
{
    mem-op:advanced-operation(
		for $n at $pos in $replace-nodes
		return (
			"replace",
			$n,
			$start-mod-qname,
			$new-nodes[$pos],
			$end-mod-qname
		)
	)
};

(:
Determine common ancestry among nodes to modify
:)
declare function mem-op:process(
    $nodes-to-modify as node()+,
    $new-nodes as node()*,
    $operation as item()*
) as node()*
{
	mem-op:process(
		$nodes-to-modify,
		$new-nodes,
		$operation,
		count($nodes-to-modify)
	)
};

declare function mem-op:process(
    $nodes-to-modify as node()+,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer
) as node()*
{
	mem-op:process(
		$nodes-to-modify,
		(),
		$new-nodes,
		$operation,
		$nodes-to-modify-size,
		(: find common ancestors :)
		reverse(mem-op:find-ancestor-intersect($nodes-to-modify, 1, $nodes-to-modify-size, ()))
	)
};

declare function mem-op:process(
    $nodes-to-modify as node()+,
    $all-nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer,
	$common-ancestors as node()*
) as node()*
{
	mem-op:process(
		$nodes-to-modify,
		$all-nodes-to-modify,
		$new-nodes,
		$operation,
		$nodes-to-modify-size,
		$common-ancestors,		
		(: get the first common parent of all the items to modify :)
		$common-ancestors[1]
	)
};

declare function mem-op:process(
    $nodes-to-modify as node()+,
    $all-nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer,
	$common-ancestors as node()*,
	$common-parent as node()?
) as node()*
{
	mem-op:process(
		$nodes-to-modify,
		$all-nodes-to-modify,
		$new-nodes,
		$operation,
		$nodes-to-modify-size,
		$common-ancestors,
		(: get all of the ancestors :)
		$common-parent/ancestor-or-self::node(),
		$common-parent
	)
};

declare function mem-op:process(
    $nodes-to-modify as node()+,
    $all-nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer,
	$common-ancestors as node()*,
	$all-ancestors as node()*,
	$common-parent as node()?
) as node()*
{
	mem-op:process(
		$nodes-to-modify,
		$all-nodes-to-modify,
		$new-nodes,
		$operation,
		$nodes-to-modify-size,
		$common-ancestors,
		$all-ancestors,		
		(: get the first common parent of all the items to modify :)
		$common-parent,
		(: create new XML trees for all the unique paths to the items to modify :)
		element mem-op:trees {
			for $mod-node in ($common-parent/child::node(),$common-parent/attribute::node()) intersect $nodes-to-modify/ancestor-or-self::node()
			let	$nodes-to-mod := ($mod-node/descendant-or-self::node(),$mod-node/descendant-or-self::node()/attribute::node()) intersect $nodes-to-modify,
				$mod-node-id := mem-op:generate-id($nodes-to-mod[1]),
				$descendant-nodes-to-mod := $nodes-to-mod except $mod-node,
				$descendant-nodes-to-mod-size := count($descendant-nodes-to-mod)
			return 
				element {QName("http://maxdewpoint.blogspot.com/memory-operations", concat('_',$mod-node-id))} {
					if ($descendant-nodes-to-mod-size eq 0)
					then 
						mem-op:process-subtree(
							$nodes-to-mod/ancestor::node() except $all-ancestors,
							$nodes-to-mod,
							$mod-node-id,
							$new-nodes,
							$operation,
							()
						)
					else
						mem-op:process(
							$descendant-nodes-to-mod,
							$nodes-to-mod,
							$new-nodes,
							$operation,
							$descendant-nodes-to-mod-size,
							(: find the ancestors that all nodes to modify have in common and reverse order for recursion up the tree :)
							reverse(mem-op:find-ancestor-intersect($descendant-nodes-to-mod, 1, $descendant-nodes-to-mod-size, ()) except $all-ancestors)
						)
				}
		}				
	)
};

declare function mem-op:process(
    $nodes-to-modify as node()+,
    $all-nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer,
	$common-ancestors as node()*,
	$all-ancestors as node()*,
	$common-parent as node()?,
	$trees as node()*
) as node()*
{
	mem-op:process(
		$nodes-to-modify,
		$all-nodes-to-modify,
		$new-nodes,
		$operation,
		$nodes-to-modify-size,
		$common-ancestors,
		$all-ancestors,
		$common-parent,
		$trees,
		count($trees)
	)
};
declare function mem-op:process(
    $nodes-to-modify as node()+,
    $all-nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer,
	$common-ancestors as node()*,
	$all-ancestors as node()*,
	$common-parent as node()?,
	$trees as node()*,
	$trees-size as xs:integer
) as node()*
{
	if (exists($common-parent))
	then
		mem-op:process-ancestors(
			$common-ancestors,
			$common-parent,
			2,
			count($common-ancestors),
			$operation,
			$all-nodes-to-modify,
			$nodes-to-modify,
			$new-nodes,
			(: merge trees in at the first common ancestor :)
			if (some $n in ($nodes-to-modify union $all-nodes-to-modify) satisfies $n is $common-parent)
			then
				mem-op:process-subtree(
					(),
					typeswitch ($common-parent)
					case element() return
						element {node-name($common-parent)} {
							mem-op:place-trees(
								$nodes-to-modify, 
								1, 
								$nodes-to-modify-size,
								$trees,
								($common-parent/attribute(),$common-parent/node()) except $nodes-to-modify/ancestor-or-self::node(),
								()
							)
						}
					case document-node() return
						document {
							mem-op:place-trees(
								$nodes-to-modify, 
								1, 
								$nodes-to-modify-size,
								$trees, 
								($common-parent/attribute(),$common-parent/node()) except $nodes-to-modify/ancestor-or-self::node(),
								()
							)
						}
					default return (),
					mem-op:generate-id($common-parent),
					$new-nodes,
					$operation,
					()
				)
			else
				typeswitch ($common-parent)
				case element() return
					element {node-name($common-parent)} {
						mem-op:place-trees(
							$nodes-to-modify, 
							1, 
							$nodes-to-modify-size,
							$trees,
							($common-parent/attribute(),$common-parent/node()) except $nodes-to-modify/ancestor-or-self::node(),
							()
						)
					}
				case document-node() return
					document {
						mem-op:place-trees(
							$nodes-to-modify, 
							1, 
							$nodes-to-modify-size,
							$trees, 
							($common-parent/attribute(),$common-parent/node()) except $nodes-to-modify/ancestor-or-self::node(),
							()
						)
					}
				default return ()
		)
	else if (exists($trees/*/node()))
	then $trees/*/node()
	else 
		for $node in $nodes-to-modify
		return
			mem-op:process-subtree(
				(),
				$node,
				mem-op:generate-id($node),
				$new-nodes,
				$operation,
				()
			)
};

(:
Creates a new subtree with the changes made based off of the operation.  
:)
declare function mem-op:process-subtree(
    $ancestors as node()*,
	$node-to-modify as node(),
	$node-to-modify-id as xs:string,
    $new-node as node()*,
    $operations as item()*,
	$ancestor-nodes-to-modify as node()*
) as node()*
{
	mem-op:process-ancestors(
		$ancestors, 
		$node-to-modify, 
		1, 
		count($ancestors), 
		$operations,
		$node-to-modify,
		$ancestor-nodes-to-modify,
		$new-node,
		let $operation := 	typeswitch ($operations)
							case xs:string return $operations
							case element(mem-op:operation)* return string($operations[mem-op:id = $node-to-modify-id]/@operation)
							default return (),
			$new-node := 	typeswitch ($operations)
							case xs:string return $new-node
							case element(mem-op:operation)* return 
								let $modifier-nodes := $new-node[mem-op:id = $node-to-modify-id]
								return ($modifier-nodes/attribute::node(),$modifier-nodes/node() except $modifier-nodes/mem-op:id)
							default return ()
		return					
			if ($operation eq "replace")
			then
				$new-node
			else if ($operation = ("insert-child","insert-child-first"))
			then
				element{ node-name($node-to-modify) }
				{
					typeswitch ($new-node)
					case attribute() return
						( if ($operation eq "insert-child-first") then ($new-node, $node-to-modify/@*) else ($node-to-modify/@*, $new-node), $node-to-modify/node() )
					default return
						( $node-to-modify/@*, if ($operation eq "insert-child-first") then ($new-node, $node-to-modify/node()) else ($node-to-modify/node(), $new-node) )
				}
			else if ($operation eq "insert-after")
			then
				($node-to-modify, $new-node)
			else if ($operation eq "insert-before")
			then
				($new-node, $node-to-modify)
			else ()	
	)
};

(:
Find all of the common ancestors of a given set of nodes 
:)
declare function mem-op:find-ancestor-intersect(
    $items as node()*,
	$current-position as xs:integer,
	$items-size as xs:integer,
    $ancestor-intersect as node()*
) as node()*
{
	if ($current-position gt $items-size)
	then $ancestor-intersect
	else
		if (exists($ancestor-intersect))
		(: if ancestor-intersect already exists intersect with the current item's ancestors :)
		then mem-op:find-ancestor-intersect(
				$items, 
				$current-position + 1, 
				$items-size, 
				$items[$current-position]/ancestor::node() intersect $ancestor-intersect
			)
		(: otherwise just use the current item's ancestors :)
		else mem-op:find-ancestor-intersect(
				$items, 
				$current-position + 1, 
				$items-size, 
				$items[$current-position]/ancestor::node()
			)
};

(:
Place newly created trees in proper order
:)
declare function mem-op:place-trees(
    $nodes-to-modify as node()+,
	$current-position as xs:integer,
	$nodes-to-modify-size as xs:integer,
    $trees as node()*,
    $remaining-nodes as node()*,
    $result as node()*
) as node()*
{
	if ($current-position gt $nodes-to-modify-size)
	then ($result,$remaining-nodes)
	else 
		mem-op:place-trees(
			$nodes-to-modify, 
			$current-position, 
			$nodes-to-modify-size, 
			$trees,
			$remaining-nodes, 
			$result,
			(: pass the current modified node :)
			$nodes-to-modify[$current-position]
		)
};

declare function mem-op:place-trees(
    $nodes-to-modify as node()+,
	$current-position as xs:integer,
	$nodes-to-modify-size as xs:integer,
    $trees as node()*,
    $remaining-nodes as node()*,
    $result as node()*,
	$current-modified as node()
) as node()*
{
	mem-op:place-trees(
		$nodes-to-modify, 
		$current-position, 
		$nodes-to-modify-size, 
		$trees,
		$remaining-nodes, 
		$result,
		$current-modified,
		(: calculate the nodes that occur previous to the current modified :)
		$remaining-nodes[. << $current-modified],
		QName("http://maxdewpoint.blogspot.com/memory-operations", concat('_',mem-op:generate-id($current-modified)))
	)
};

declare function mem-op:place-trees(
    $nodes-to-modify as node()+,
	$current-position as xs:integer,
	$nodes-to-modify-size as xs:integer,
    $trees as node()*,
    $remaining-nodes as node()*,
    $result as node()*,
	$current-modified as node(),
	$prev-nodes as node()*,
	$current-modified-id as xs:QName
) as node()*
{
	mem-op:place-trees(
		$nodes-to-modify, 
		$current-position, 
		$nodes-to-modify-size, 
		$trees,
		$remaining-nodes, 
		$result,
		$current-modified,
		$prev-nodes,
		$current-modified-id,
		$trees/*[node-name(.) eq $current-modified-id]
	)
};

declare function mem-op:place-trees(
    $nodes-to-modify as node()+,
	$current-position as xs:integer,
	$nodes-to-modify-size as xs:integer,
    $trees as node()*,
    $remaining-nodes as node()*,
    $result as node()*,
	$current-modified as node(),
	$prev-nodes as node()*,
	$current-modified-id as xs:QName,
	$current-tree as node()*
) as node()*
{
	mem-op:place-trees(
		$nodes-to-modify, 
		$current-position + 1, 
		$nodes-to-modify-size, 
		$trees,
		(: filter out nodes already used :)
		$remaining-nodes except $prev-nodes, 
		(: pass the result we already have, plus previous nodes and the new tree :)
		($result,$prev-nodes, $current-tree/@* except $current-tree/@mem-op:id, $current-tree/node())
	)
};


(:
Recursively go up the tree to build new XML
:)
declare function mem-op:process-ancestors(
    $ancestors as node()*,
	$last-ancestor as node()?,
	$current-position as xs:integer,
	$ancestor-size as xs:integer,
	$operations as item()*,
	$nodes-to-modify as node()*,
	$ancestor-nodes-to-modify as node()*,
	$new-node as node()*,
	$result as node()*
) as node()*
{
    if ($current-position gt $ancestor-size)
	then $result
	else 
		mem-op:process-ancestors(
			$ancestors,
			$last-ancestor,
			$current-position,
			$ancestor-size,
			$operations,
			$nodes-to-modify,
			$ancestor-nodes-to-modify,
			$new-node,
			$result,
			$ancestors[$current-position]
		)
};

declare function mem-op:process-ancestors(
    $ancestors as node()*,
	$last-ancestor as node()?,
	$current-position as xs:integer,
	$ancestor-size as xs:integer,
	$operations as item()*,
	$nodes-to-modify as node()*,
	$ancestor-nodes-to-modify as node()*,
	$new-node as node()*,
	$result as node()*,
	$currrent-ancestor as node()
) as node()*
{
	mem-op:process-ancestors(
		$ancestors,
		$currrent-ancestor,
		$current-position + 1,
		$ancestor-size,
		$operations,
		$nodes-to-modify,
		$ancestor-nodes-to-modify intersect $currrent-ancestor/ancestor::node(),
		$new-node,
		if (some $n in $ancestor-nodes-to-modify satisfies $n is $currrent-ancestor)
		then 
			mem-op:process-subtree(
				(),
				typeswitch ($currrent-ancestor)
				case element() return
					element {node-name($currrent-ancestor)} {
						$currrent-ancestor/attribute() except $nodes-to-modify,
						$last-ancestor/preceding-sibling::node(),
						$result,
						$last-ancestor/following-sibling::node()
					}				
				case document-node() return
					document {
						$result
					}
				default return (),
				mem-op:generate-id($currrent-ancestor),
				$new-node,
				$operations,
				()
			)
		else
			typeswitch ($currrent-ancestor)
			case element() return
				element {node-name($currrent-ancestor)} {
					$currrent-ancestor/attribute() except $nodes-to-modify,
					$last-ancestor/preceding-sibling::node(),
					$result,
					$last-ancestor/following-sibling::node()
				}				
			case document-node() return
				document {
					$result
				}
			default return ()
	)	
};

declare function mem-op:generate-id($node as node()) {
	generate-id($node)
};