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
@version 0.5.1
@description This is a module with function changing XML in memory by creating subtrees using the ancestor, preceding-sibling, and following-sibling axes
				and intersect/except expressions. Requires MarkLogic 6+.
:)

module namespace mem-op = "http://maxdewpoint.blogspot.com/memory-operations";
import module namespace node-op = "http://maxdewpoint.blogspot.com/node-operations" at "node-operations.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare namespace xdmp = "http://marklogic.com/xdmp";
declare namespace map = "http://marklogic.com/xdmp/map";

declare option xdmp:mapping "true";

declare %private variable $queue as map:map := map:map();
declare %private variable $transform-functions as map:map := map:map();

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
Queue insert a child into the node
:)
declare function mem-op:insert-child(
	$transaction-id as xs:string,
    $parent-node as element()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:queue($transaction-id, $parent-node, $new-nodes, "insert-child")
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
Queue insert as first child into the node
:)
declare function mem-op:insert-child-first(
	$transaction-id as xs:string,
    $parent-node as element()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:queue($transaction-id, $parent-node, $new-nodes, "insert-child-first")
};

(:
Insert a sibling before the node
:)
declare function mem-op:insert-before(
    $sibling as node()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:process($sibling, $new-nodes, "insert-before")
};

(:
Queue insert a sibling before the node
:)
declare function mem-op:insert-before(
	$transaction-id as xs:string,
	$sibling as node()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:queue($transaction-id, $sibling, $new-nodes, "insert-before")
};

(:
Insert a sibling after the node
:)
declare function mem-op:insert-after(
    $sibling as node()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:process($sibling, $new-nodes, "insert-after")
};

(:
Queue insert a sibling after the node
:)
declare function mem-op:insert-after(
	$transaction-id as xs:string,
    $sibling as node()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:queue($transaction-id, $sibling, $new-nodes, "insert-after")
};

(:
Replace the node
:)
declare function mem-op:replace(
    $replace-nodes as node()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:process($replace-nodes except $replace-nodes/descendant::node(), $new-nodes, "replace")
};
(:
Queue replace of the node
:)
declare function mem-op:replace(
	$transaction-id as xs:string,
    $replace-nodes as node()+,
    $new-nodes as node()*
) as node()?
{
	mem-op:queue($transaction-id, $replace-nodes except $replace-nodes/descendant::node(), $new-nodes, "replace")
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
Queue delete the node
:)
declare function mem-op:delete(
	$transaction-id as xs:string,
	$delete-nodes as node()+
) as node()?
{
	mem-op:queue($transaction-id,$delete-nodes except $delete-nodes/descendant::node(), (), "replace")
};

(:
Rename a node
:)
declare function mem-op:rename(
    $nodes-to-rename as node()+,
	$new-name as xs:QName
) as node()?
{
	mem-op:process($nodes-to-rename, element {$new-name} {}, "rename")
};
(:
Queue renaming of node
:)
declare function mem-op:rename(
	$transaction-id as xs:string,
    $nodes-to-rename as node()+,
	$new-name as xs:QName
) as node()?
{
	mem-op:queue($transaction-id,$nodes-to-rename, element {$new-name} {}, "rename")
};

(:
Replaces a value of an element or attribute
:)
declare function mem-op:replace-value(
    $nodes-to-change as node()+,
	$value as xs:anyAtomicType?
) as node()?
{
	mem-op:process($nodes-to-change, text {$value}, "replace-value")
};
(:
Queue replacement of a value of an element or attribute
:)
declare function mem-op:replace-value(
	$transaction-id as xs:string,
	$nodes-to-change as node()+,
	$value as xs:anyAtomicType?
) as node()?
{
	mem-op:queue($transaction-id, $nodes-to-change, text {$value}, "replace-value")
};

(:
Replaces with the result of the passed function
:)
declare function mem-op:transform(
    $nodes-to-change as node()+,
	$transform-function as function(node()) as node()*
) as node()?
{
	(xdmp:key-from-QName((function-name($transform-function),xs:QName('_' || string(xdmp:random())))[1]) || '#' || string(function-arity($transform-function))) !
	(
	map:put($transform-functions,.,$transform-function),
	mem-op:process($nodes-to-change, text {.}, "transform"),
	map:delete($transform-functions,.)	
	)
};

(:
Queues the replacement of the node with the result of the passed function
:)
declare function mem-op:transform(
	$transaction-id as xs:string,
	$nodes-to-change as node()+,
	$transform-function as function(node()) as node()*
) as node()?
{
	(xdmp:key-from-QName((function-name($transform-function),xs:QName('_' || string(xdmp:random())))[1]) || '#' || string(function-arity($transform-function))) !
	(
	map:put(map:get($queue,$transaction-id),.,$transform-function),
	mem-op:queue($transaction-id, $nodes-to-change, text {.}, "transform")
	)
};

(:
Turn on and off queueing for later execution
:)
declare function mem-op:copy($node-to-copy as node()) as xs:string
{
	concat(
		mem-op:generate-id($node-to-copy),
		current-dateTime()
	) 
	!
	(
		map:put($queue,.,map:map() ! (map:put(.,'copy',$node-to-copy),.)),
		.
	)
};

(:
Queue actions for later execution
:)
declare function mem-op:execute($transaction-id as xs:string) as node()?
{
	map:get($queue,$transaction-id) !
	(
	if (exists(map:get(.,'nodes-to-modify')))
	then
		mem-op:process(
			$transaction-id,
			map:get(.,'nodes-to-modify') union (),
			map:get(.,'modifier-nodes'),
			map:get(.,'operation')
		)
	else 
		validate lax {
			map:get(.,'copy')
		}
	),
	map:delete($queue,$transaction-id)
	
};

(: Begin private functions! :)

(:
Queue actions for later execution
:)
declare %private function mem-op:queue(
	$transaction-id as xs:string,
    $nodes-to-modify as node()+,
    $modifier-nodes as node()*,
    $operation as xs:string?
) as empty-sequence()
{
	map:get($queue,$transaction-id) !
	(
	let $modified-node-ids as element(mem-op:id)* := 
									for $mn in $nodes-to-modify 
									return element mem-op:id {mem-op:generate-id($mn)},
		$modifier-attributes as attribute()* := $modifier-nodes[self::attribute()]
	return (
		map:put(.,'operation',
			(
				element mem-op:operation {
					attribute operation {$operation},
					$modified-node-ids
				},
				map:get(.,'operation')
			)
		),
		map:put(.,'nodes-to-modify',
			(		
				$nodes-to-modify,
				map:get(.,'nodes-to-modify') intersect map:get(.,'copy')/descendant-or-self::node()/(@*|.)
			)
		),
		map:put(.,'modifier-nodes',
			(		
				element mem-op:modifier-nodes {
					attribute mem-op:operation {$operation},
					$modifier-attributes,
					$modified-node-ids,
					$modifier-nodes except $modifier-attributes
				},
				map:get(.,'modifier-nodes')
			)
		)
	)
	)
};

(:
Determine common ancestry among nodes to modify
TODO: Clean up process functions
:)
declare %private function mem-op:process(
    $nodes-to-modify as node()+,
    $new-nodes as node()*,
    $operation as item()*
) as node()*
{
	mem-op:process(
		(),
		$nodes-to-modify,
		$new-nodes,
		$operation
	)
};

declare %private function mem-op:process(
	$transaction-id as xs:string?,	
    $nodes-to-modify as node()+,
    $new-nodes as node()*,
    $operation as item()*
) as node()*
{
	mem-op:process(
		$transaction-id,	
		$nodes-to-modify,
		$new-nodes,
		$operation,
		count($nodes-to-modify)
	)
};

declare %private function mem-op:process(
	$transaction-id as xs:string?,
    $nodes-to-modify as node()+,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer
) as node()*
{
	mem-op:process(
		$transaction-id,
		$nodes-to-modify,
		(),
		$new-nodes,
		$operation,
		$nodes-to-modify-size,
		(: find common ancestors :)
		mem-op:find-ancestor-intersect($nodes-to-modify, 1, $nodes-to-modify-size, ())
		except
		(
		  if (exists($transaction-id))
		  then map:get(map:get($queue,$transaction-id),'copy')/ancestor::node()
		  else ()
		)
	)
};

declare %private function mem-op:process(
	$transaction-id as xs:string?,
    $nodes-to-modify as node()+,
    $all-nodes-to-modify as node()*,
    $new-nodes as node()*,
    $operation as item()*,
	$nodes-to-modify-size as xs:integer,
	$common-ancestors as node()*
) as node()*
{
	mem-op:process(
		$transaction-id,
		$nodes-to-modify,
		$all-nodes-to-modify,
		$new-nodes,
		$operation,
		$nodes-to-modify-size,
		$common-ancestors,		
		(: get the first common parent of all the items to modify :)
		$common-ancestors[fn:last()]
	)
};

declare %private function mem-op:process(
	$transaction-id as xs:string?,
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
		$transaction-id,
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

declare %private function mem-op:process(
	$transaction-id as xs:string?,
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
		$transaction-id,
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
				$transaction-id,
				($common-parent/child::node(),$common-parent/attribute::node()) intersect $nodes-to-modify/ancestor-or-self::node(),
				$all-nodes-to-modify union $nodes-to-modify,
				$new-nodes,
				$operation,
				$all-ancestors
			)
		}
	)
};

declare %private function mem-op:process(
	$transaction-id as xs:string?,
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
	if (exists($common-parent) and not(exists($transaction-id) and $nodes-to-modify is map:get(map:get($queue,$transaction-id),'copy')))
	then
		mem-op:process-ancestors(
			$transaction-id,
			$common-ancestors 
			except $common-parent,
			$common-parent,
			$operation,
			$all-nodes-to-modify,
			($nodes-to-modify union $all-nodes-to-modify) intersect $common-ancestors,
			$new-nodes,
			let $placed-trees as node()* := 
						  mem-op:place-trees(
							$nodes-to-modify, 
							$common-parent/(@*|node()) except $nodes-to-modify/ancestor-or-self::node(),
							$trees
						  ),
				$new-common-parent :=
					typeswitch ($common-parent)
					case element() return
						element {node-name($common-parent)} {
						  $placed-trees
						}
					case document-node() return
						document {
						  $placed-trees
						}
					default return ()
			return
			(: merge trees in at the first common ancestor :)
			if (some $n in ($nodes-to-modify union $all-nodes-to-modify) satisfies $n is $common-parent)
			then
				mem-op:process-subtree(
					$transaction-id,
					(),
					$new-common-parent,
					mem-op:generate-id($common-parent),
					$new-nodes,
					$operation,
					()
				)
			else
				$new-common-parent
		)
	else if (exists($trees/*))
	then $trees/*/node()
	else (
		for $node in $nodes-to-modify
		return
			mem-op:process-subtree(
				$transaction-id,
				(),
				$node,
				mem-op:generate-id($node),
				$new-nodes,
				$operation,
				()
			)
		)
};


declare %private function mem-op:build-subtree(
	$transaction-id as xs:string?,
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
						$transaction-id,
						$mod-node/ancestor::node() except $all-ancestors,
						$mod-node,
						$mod-node-id,
						$new-nodes,
						$operations,
						()
					)
				else
					mem-op:process(
						$transaction-id,
						$descendant-nodes-to-mod,
						$nodes-to-mod,
						$new-nodes,
						$operations,
						$descendant-nodes-to-mod-size,
						(: find the ancestors that all nodes to modify have in common :)
						mem-op:find-ancestor-intersect($descendant-nodes-to-mod, 1, $descendant-nodes-to-mod-size, ()) except $all-ancestors
					)
			} 

};

(:
Creates a new subtree with the changes made based off of the operation.  
:)
declare %private function mem-op:process-subtree(
	$transaction-id as xs:string?,
    $ancestors as node()*,
	$node-to-modify as node(),
	$node-to-modify-id as xs:string,
    $new-node as node()*,
    $operations as item()*,
	$ancestor-nodes-to-modify as node()*
) as node()*
{
	mem-op:process-ancestors(
		$transaction-id,
		$ancestors, 
		(),
		$operations,
		$node-to-modify,
		$ancestor-nodes-to-modify,
		$new-node,
		mem-op:build-new-xml(
			$transaction-id,
			$node-to-modify, 
			typeswitch($operations)
			case xs:string return $operations
			default return $operations[mem-op:id = $node-to-modify-id]/@operation/fn:string(.), 
			typeswitch($new-node)
			case element(mem-op:modifier-nodes)* return 
				$new-node[mem-op:id = $node-to-modify-id]
			default return 
					element mem-op:modifier-nodes {
						attribute mem-op:operation {$operations},
						$new-node
					}
		)
	)
};

(:
Find all of the common ancestors of a given set of nodes 
:)
declare %private function mem-op:find-ancestor-intersect(
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
declare %private function mem-op:place-trees(
    $nodes-to-modify as node()+,
    $merging-nodes as node()*,
    $trees as element(mem-op:trees)
) as node()*
{
    (: fold left over the process trees function. :)
	fold-left(
	   mem-op:place-trees(
	      $nodes-to-modify,
		  $merging-nodes,
		  $trees,
		  ?,
		  ?
		),
		(),
		$nodes-to-modify
	)
};

(: This function is passed into fold-left. It places the new XML in the proper order for document creation. :)
declare %private function mem-op:place-trees(
    $nodes-to-modify as node()+,
    $merging-nodes as node()*,
    $trees as element(mem-op:trees),
    $result as node()*,
    $node-to-modify as node()?
) as node()*
{
    let $previous-mod-node := ($nodes-to-modify intersect $node-to-modify/following::node())[1],
        $current-modified-id := QName("http://maxdewpoint.blogspot.com/memory-operations",fn:concat("_",mem-op:generate-id($node-to-modify)))
    return 
    (
        (: If modify node is the first node then add nodes that come before :)
        if ($node-to-modify is $nodes-to-modify[1])
        then node-op:inbetween($merging-nodes,(),$node-to-modify)
        else (),
        $result,
        $trees/*[fn:node-name(.) eq $current-modified-id]/(@*|node()),
        node-op:inbetween($merging-nodes,$node-to-modify,$previous-mod-node)
    )
};

(:
Go up the tree to build new XML using a fold-left. This is used when there are no side steps to merge in, only a direct path.
:)
declare %private function mem-op:process-ancestors(
	$transaction-id as xs:string?,
    $ancestors as node()*,
    $last-ancestor as node()?,
	$operations as item()*,
	$nodes-to-modify as node()*,
	$ancestor-nodes-to-modify as node()*,
	$new-node as node()*,
	$base as node()*
) as node()*
{
    fold-left(
        mem-op:process-ancestors(
			$transaction-id,
			$ancestors,
			$last-ancestor,
			$operations,
			$nodes-to-modify,
			$ancestor-nodes-to-modify,
			$new-node,
			$base,
			?,
			?
		),
		$base,
		reverse($ancestors)
    )
};

declare %private function mem-op:process-ancestors(
	$transaction-id as xs:string?,
    $ancestors as node()*,
    $last-ancestor as node()?,
	$operations as item()*,
	$nodes-to-modify as node()*,
	$ancestor-nodes-to-modify as node()*,
	$new-node as node()*,
	$baseline as node()*,
	$result as node()*,
	$current-ancestor as node()
) as node()*
{
    let $last-ancestor := ($ancestors[. >> $current-ancestor],$last-ancestor)[1],
        $preceding-siblings := $last-ancestor/preceding-sibling::node(),
        $following-siblings := $last-ancestor/following-sibling::node(),
        $reconstructed-ancestor :=
        		typeswitch ($current-ancestor)
				case element() return
					element {node-name($current-ancestor)} {
						$current-ancestor/attribute() except $nodes-to-modify,
						$preceding-siblings,
						($result,$baseline)[1],
						$following-siblings
					}				
				case document-node() return
					document {
						($result,$baseline)[1]
					}
				default return ()
	return
	if (some $n in $ancestor-nodes-to-modify satisfies $n is $current-ancestor)
	then 
			mem-op:process-subtree(
				$transaction-id,
				(),
				$reconstructed-ancestor,
				mem-op:generate-id($current-ancestor),
				$new-node,
				$operations,
				()
			)
	else $reconstructed-ancestor
};

(: Generate an id unique to a node in memory. Right now using fn:generate-id. :)
declare %private function mem-op:generate-id($node as node()) {
	generate-id($node)
};

(: This is where the transformations to the XML take place and this module can be extended. :)
declare %private function mem-op:build-new-xml($transaction-id as xs:string?, $node as node(), $operations as xs:string*, $modifier-nodes as element(mem-op:modifier-nodes)*) {
	if (empty($operations))
	then $node
	else 
		mem-op:build-new-xml(
			$transaction-id,
			let $operation as xs:string := 	head($operations),
				$new-nodes as node()* := 
								let $modifier-nodes := $modifier-nodes[@mem-op:operation eq $operation]
								return ($modifier-nodes/attribute::node() except $modifier-nodes/@mem-op:operation,
										$modifier-nodes/node() except $modifier-nodes/mem-op:id)
			return					
				switch ($operation)
				case "replace" 
					return $new-nodes
				case "insert-child"
					return
					element{ node-name($node) }
					{
						let $attributes-to-insert := $new-nodes[self::attribute()]
						return
							($node/@*, $attributes-to-insert, $node/node(), $new-nodes except $attributes-to-insert)
					}
				case "insert-child-first"
					return
					element{ node-name($node) }
					{
						let $attributes-to-insert := $new-nodes[self::attribute()]
						return
							($attributes-to-insert, $node/@*, $new-nodes except $attributes-to-insert, $node/node())
					}
				case "insert-after"
					return ($node, $new-nodes)
				case "insert-before"
					return ($new-nodes, $node)
				case 'rename'
					return
					element{ node-name(($new-nodes[self::element()])[1]) }
					{
						$node/@*,
						$node/node()
					}
				case 'replace-value'
					return
					typeswitch ($node)
					case attribute() return
						attribute { node-name($node) }
						{
							$new-nodes
						}
					case element() return
						element { node-name($node) }
						{
							$node/@*,
							$new-nodes
						}
					case processing-instruction() return
						processing-instruction { node-name($node) }
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
				case 'transform'
					return 
						if (exists($transaction-id))
						then map:get(map:get($queue,$transaction-id),string($new-nodes))($node)
						else map:get($transform-functions,string($new-nodes))($node)
				default return (),
			tail($operations),
			$modifier-nodes
		)
};