xquery version "1.0-ml";
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
@version 0.4.0
@description This is a module with function changing XML in memory by creating subtrees using the ancestor, preceding-sibling, and following-sibling axes
				and intersect/except expressions.
:)

module namespace mem-op = "http://maxdewpoint.blogspot.com/memory-operations";
declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "true";

declare private variable $queued as xs:boolean := fn:false();
declare private variable $queue as map:map := map:map();

(:
Insert a child into the node
:)
declare function mem-op:insert-child(
    $parent-node as element()+,
    $new-nodes as node()*
) as node()?
{
	if ($queued)
	then 
		mem-op:queue($parent-node, $new-nodes, "insert-child")
	else
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
	if ($queued)
	then 
		mem-op:queue($parent-node, $new-nodes, "insert-child-first")
	else
		mem-op:process($parent-node, $new-nodes, "insert-child-first")
};

(:
Insert a sibling before the node
:)

declare function mem-op:insert-before(
    $sibling as node()+,
    $new-nodes as node()*
) as node()?
{
	if ($queued)
	then 
		mem-op:queue($sibling, $new-nodes, "insert-before")
	else
		mem-op:process($sibling, $new-nodes, "insert-before")
};

(:
Insert a sibling after the node
:)
declare function mem-op:insert-after(
    $sibling as node()+,
    $new-nodes as node()*
) as node()?
{
	if ($queued)
	then 
		mem-op:queue($sibling, $new-nodes, "insert-after")
	else
		mem-op:process($sibling, $new-nodes, "insert-after")
};

(:
Replace the node
:)
declare function mem-op:replace(
    $replace-nodes as node()+,
    $new-nodes as node()*
) as node()?
{
	if ($queued)
	then 
		mem-op:queue($replace-nodes except $replace-nodes/descendant::node(), $new-nodes, "replace")
	else
		mem-op:process($replace-nodes except $replace-nodes/descendant::node(), $new-nodes, "replace")
};

(:
Delete the node
:)
declare function mem-op:delete(
    $delete-nodes as node()+
) as node()?
{
	if ($queued)
	then 
		mem-op:queue($delete-nodes except $delete-nodes/descendant::node(), (), "replace")
	else
		mem-op:process($delete-nodes except $delete-nodes/descendant::node(), (), "replace")
};

(:
Rename a node
:)
declare function mem-op:rename(
    $nodes-to-rename as node()+,
	$new-name as xs:QName
) as node()?
{
	if ($queued)
	then 
		mem-op:queue($nodes-to-rename, element {$new-name} {}, "rename")
	else
		mem-op:process($nodes-to-rename, element {$new-name} {}, "rename")
};

(:
Replaces a value of an element or attribute
:)
declare function mem-op:replace-value(
    $nodes-to-change as node()+,
	$value as xs:string
) as node()?
{
	if ($queued)
	then 
		mem-op:queue($nodes-to-change, text {$value}, "replace-value")
	else
		mem-op:process($nodes-to-change, text {$value}, "replace-value")
};

(:
Turn on and off queueing for later execution
:)
declare function mem-op:queue() as empty-sequence()
{
	xdmp:set($queued,not($queued))
};

(:
Determines if actions are currently being queued
:)
declare function mem-op:queueing() as xs:boolean
{
	$queued
};

(:
Queue actions for later execution
:)
declare function mem-op:execute() as node()?
{
	mem-op:process(
		map:get($queue,'nodes-to-modify') union (),
		map:get($queue,'modifier-nodes'),
		map:get($queue,'operation')
	),
	map:clear($queue),
	mem-op:queue()
};

(: Begin private functions! :)

(:
Queue actions for later execution
:)
declare private function mem-op:queue(
    $nodes-to-modify as node()+,
    $modifier-nodes as node()*,
    $operation as xs:string?
) as empty-sequence()
{
	let $modified-node-ids as element(mem-op:id)* := 
									for $mn in $nodes-to-modify 
									return element mem-op:id {mem-op:generate-id($mn)},
		$modifier-attributes as attribute()* := $modifier-nodes[self::attribute()]
	return (
		map:put($queue,'operation',
			(
				element mem-op:operation {
					attribute operation {$operation},
					$modified-node-ids
				},
				map:get($queue,'operation')
			)
		),
		map:put($queue,'nodes-to-modify',
			(		
				$nodes-to-modify,
				map:get($queue,'nodes-to-modify')
			)
		),
		map:put($queue,'modifier-nodes',
			(		
				element mem-op:modifier-nodes {
					$modifier-attributes,
					$modified-node-ids,
					$modifier-nodes except $modifier-attributes
				},
				map:get($queue,'modifier-nodes')
			)
		)
	)
};

(:
Determine common ancestry among nodes to modify
:)
declare private function mem-op:process(
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

declare private function mem-op:process(
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

declare private function mem-op:process(
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

declare private function mem-op:process(
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

declare private function mem-op:process(
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
			mem-op:build-subtree(
				($common-parent/child::node(),$common-parent/attribute::node()) intersect $nodes-to-modify/ancestor-or-self::node(),
				$nodes-to-modify,
				$new-nodes,
				$operation,
				$all-ancestors
			)
		}
	)
};

declare private function mem-op:process(
    $nodes-to-modify as node()+,
    $all-nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer,
	$common-ancestors as node()*,
	$all-ancestors as node()*,
	$common-parent as node()?,
	$trees as element(mem-op:trees)
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
	else if (exists($trees/*))
	then $trees/*/node()
	else (
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
		)
};

declare private function mem-op:build-subtree(
    $mod-node as node(),
    $nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operations as item()*,
	$all-ancestors as node()*
) as node()*
{
		let	$nodes-to-mod := ($mod-node/descendant-or-self::node(),$mod-node/descendant-or-self::node()/attribute::node()) intersect $nodes-to-modify,
			$mod-node-id := mem-op:generate-id($nodes-to-mod[1]),
			$descendant-nodes-to-mod := $nodes-to-mod except $mod-node,
			$descendant-nodes-to-mod-size := count($descendant-nodes-to-mod)
		return 
			element {fn:QName("http://maxdewpoint.blogspot.com/memory-operations",fn:concat("_",$mod-node-id))} {
				if ($descendant-nodes-to-mod-size eq 0)
				then 
					mem-op:process-subtree(
						$nodes-to-mod/ancestor::node() except $all-ancestors,
						$nodes-to-mod,
						$mod-node-id,
						$new-nodes,
						$operations,
						()
					)
				else
					mem-op:process(
						$descendant-nodes-to-mod,
						$nodes-to-mod,
						$new-nodes,
						$operations,
						$descendant-nodes-to-mod-size,
						(: find the ancestors that all nodes to modify have in common and reverse order for recursion up the tree :)
						reverse(mem-op:find-ancestor-intersect($descendant-nodes-to-mod, 1, $descendant-nodes-to-mod-size, ()) except $all-ancestors)
					)
			} 

};

(:
Creates a new subtree with the changes made based off of the operation.  
:)
declare private function mem-op:process-subtree(
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
			$new-nodes as node()* := 	
							typeswitch ($operations)
							case xs:string return $new-node
							case element(mem-op:operation)* return 
								let $modifier-nodes := $new-node[mem-op:id = $node-to-modify-id]
								return ($modifier-nodes/attribute::node(),$modifier-nodes/node() except $modifier-nodes/mem-op:id)
							default return ()
		return					
			if ($operation eq "replace")
			then
				$new-nodes
			else if ($operation = ("insert-child","insert-child-first"))
			then
				element{ node-name($node-to-modify) }
				{
					for $new-node in $new-nodes
					return
						typeswitch ($new-node)
						case attribute() return
							( if ($operation eq "insert-child-first") then ($new-node, $node-to-modify/@*) else ($node-to-modify/@*, $new-node), $node-to-modify/node() )
						default return
							( $node-to-modify/@*, if ($operation eq "insert-child-first") then ($new-node, $node-to-modify/node()) else ($node-to-modify/node(), $new-node) )
				}
			else if ($operation eq "insert-after")
			then
				($node-to-modify, $new-nodes)
			else if ($operation eq "insert-before")
			then
				($new-node, $node-to-modify)
			else if ($operation eq 'rename')
			then
				element{ node-name($new-nodes[1]) }
				{
					$node-to-modify/@*,
					$node-to-modify/node()
				}
			else if ($operation eq 'replace-value')
			then
				typeswitch ($node-to-modify)
				case attribute() return
					attribute { node-name($node-to-modify) }
					{
						$new-nodes
					}
				case element() return
					element { node-name($node-to-modify) }
					{
						$node-to-modify/@*,
						$new-nodes
					}
				case processing-instruction() return
					processing-instruction { node-name($node-to-modify) }
					{
						$new-nodes
					}
				case comment() return
					comment
					{
						$new-nodes
					}
				case text() return
					$new-nodes
				default return ()
			else ()	
	)
};

(:
Find all of the common ancestors of a given set of nodes 
:)
declare private function mem-op:find-ancestor-intersect(
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
declare private function mem-op:place-trees(
    $nodes-to-modify as node()+,
	$current-position as xs:integer,
	$nodes-to-modify-size as xs:integer,
    $trees as element(mem-op:trees),
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

declare private function mem-op:place-trees(
    $nodes-to-modify as node()+,
	$current-position as xs:integer,
	$nodes-to-modify-size as xs:integer,
    $trees as element(mem-op:trees),
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
		fn:QName("http://maxdewpoint.blogspot.com/memory-operations",fn:concat('_',mem-op:generate-id($current-modified)))
	)
};

declare private function mem-op:place-trees(
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
		$trees/*[fn:node-name(.) eq $current-modified-id]
	)
};

declare private function mem-op:place-trees(
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
		($result,$prev-nodes, $current-tree/@*, $current-tree/node())
	)
};


(:
Recursively go up the tree to build new XML
:)
declare private function mem-op:process-ancestors(
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
	then ($result)
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

declare private function mem-op:process-ancestors(
    $ancestors as node()*,
	$last-ancestor as node()?,
	$current-position as xs:integer,
	$ancestor-size as xs:integer,
	$operations as item()*,
	$nodes-to-modify as node()*,
	$ancestor-nodes-to-modify as node()*,
	$new-node as node()*,
	$result as node()*,
	$current-ancestor as node()
) as node()*
{
	mem-op:process-ancestors(
		$ancestors,
		$current-ancestor,
		$current-position + 1,
		$ancestor-size,
		$operations,
		$nodes-to-modify,
		$ancestor-nodes-to-modify intersect $current-ancestor/ancestor::node(),
		$new-node, 
		if (some $n in $ancestor-nodes-to-modify satisfies $n is $current-ancestor)
		then 
			mem-op:process-subtree(
				(),
				typeswitch ($current-ancestor)
				case element() return
					element {node-name($current-ancestor)} {
						$current-ancestor/attribute() except $nodes-to-modify,
						$last-ancestor/preceding-sibling::node(),
						$result,
						$last-ancestor/following-sibling::node()
					}				
				case document-node() return
					document {
						$result
					}
				default return (),
				mem-op:generate-id($current-ancestor),
				$new-node,
				$operations,
				()
			)
		else
			typeswitch ($current-ancestor)
			case element() return
				element {node-name($current-ancestor)} {
					$current-ancestor/attribute() except $nodes-to-modify,
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

declare private function mem-op:generate-id($node as node()) {
	generate-id($node)
};