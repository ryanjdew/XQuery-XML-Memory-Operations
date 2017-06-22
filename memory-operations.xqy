xquery version "1.0-ml";
(:~
Copyright (c) 2013 Ryan Dew

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

@author Ryan Dew (ryan.j.dew@gmail.com)
@version 1.1.0
@description This is a module with function changing XML in memory by creating subtrees using the ancestor, preceding-sibling, and following-sibling axes
				and intersect/except expressions. Requires MarkLogic 6+.
~:)
module namespace mem-op="http://maxdewpoint.blogspot.com/memory-operations";
import module namespace node-op="http://maxdewpoint.blogspot.com/node-operations" at "node-operations.xqy";
declare default function namespace "http://www.w3.org/2005/xpath-functions";
declare namespace xdmp="http://marklogic.com/xdmp";
declare namespace map="http://marklogic.com/xdmp/map";
declare option xdmp:mapping "true";
declare option xdmp:copy-on-validate "true";
declare %private variable $queue as map:map := map:map();
declare %private variable $transform-functions as map:map := map:map();

(: Insert a child into the node :)
declare function mem-op:insert-child(
  $parent-node as element()+,
  $new-nodes as node()*)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($parent-node[1]))
  let $_queue := 
    mem-op:queue(
    $transaction-id, $parent-node, $new-nodes, "insert-child")
  return
    mem-op:execute($transaction-id)
};

(: Queue insert a child into the node :)
declare function mem-op:insert-child(
  $transaction-id as xs:string,
  $parent-node as element()*,
  $new-nodes as node()*)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id, $parent-node, $new-nodes, "insert-child")
};

(: Insert as first child into the node :)
declare function mem-op:insert-child-first(
  $parent-node as element()+,
  $new-nodes as node()*)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($parent-node[1]))
  let $_queue := 
    mem-op:queue(
      $transaction-id,
      $parent-node,
      $new-nodes,
      "insert-child-first")
  return
    mem-op:execute($transaction-id)
};

(: Queue insert as first child into the node :)
declare function mem-op:insert-child-first(
  $transaction-id as xs:string,
  $parent-node as element()*,
  $new-nodes as node()*)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id,
    $parent-node,
    $new-nodes,
    "insert-child-first")
};

(: Insert a sibling before the node :)
declare function mem-op:insert-before(
  $sibling as node()+,
  $new-nodes as node()*)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($sibling[1]))
  let $_queue := 
    mem-op:queue(
    $transaction-id, $sibling, $new-nodes, "insert-before")
  return
    mem-op:execute($transaction-id)
};

(: Queue insert a sibling before the node :)
declare function mem-op:insert-before(
  $transaction-id as xs:string,
  $sibling as node()*,
  $new-nodes as node()*)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id, $sibling, $new-nodes, "insert-before")
};

(: Insert a sibling after the node :)
declare function mem-op:insert-after(
  $sibling as node()+,
  $new-nodes as node()*)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($sibling[1]))
  let $_queue := 
    mem-op:queue($transaction-id, $sibling, $new-nodes, "insert-after")
  return
    mem-op:execute($transaction-id)
};

(: Queue insert a sibling after the node :)
declare function mem-op:insert-after(
  $transaction-id as xs:string,
  $sibling as node()*,
  $new-nodes as node()*)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id, $sibling, $new-nodes, "insert-after")
};

(: Replace the node :)
declare function mem-op:replace(
  $replace-nodes as node()+,
  $new-nodes as node()*)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($replace-nodes[1]))
  let $_queue := 
    mem-op:queue(
      $transaction-id,
      $replace-nodes except $replace-nodes/descendant::node(),
      $new-nodes,
      "replace")
  return
    mem-op:execute($transaction-id)
};

(: Queue replace of the node :)
declare function mem-op:replace(
  $transaction-id as xs:string,
  $replace-nodes as node()*,
  $new-nodes as node()*)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id,
    $replace-nodes except $replace-nodes/descendant::node(),
    $new-nodes,
    "replace")
};

(: Delete the node :)
declare function mem-op:delete($delete-nodes as node()+)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($delete-nodes[1]))
  let $_queue := 
    mem-op:queue(
      $transaction-id,
      $delete-nodes except $delete-nodes/descendant::node(),
      (),
      "replace")
  return
    mem-op:execute($transaction-id)
};

(: Queue delete the node :)
declare function mem-op:delete(
  $transaction-id as xs:string,
  $delete-nodes as node()*)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id,
    $delete-nodes except $delete-nodes/descendant::node(),
    (),
    "replace")
};

(: Rename a node :)
declare function mem-op:rename(
  $nodes-to-rename as node()+,
  $new-name as xs:QName)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($nodes-to-rename[1]))
  let $_queue :=
    mem-op:queue(
      $transaction-id,
      $nodes-to-rename,
      element { $new-name } { },
      "rename")
  return
    mem-op:execute($transaction-id)
};

(: Queue renaming of node :)
declare function mem-op:rename(
  $transaction-id as xs:string,
  $nodes-to-rename as node()*,
  $new-name as xs:QName)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id,
    $nodes-to-rename,
    element { $new-name } { },
    "rename")
};

(: Replaces a value of an element or attribute :)
declare function mem-op:replace-value(
  $nodes-to-change as node()+,
  $value as xs:anyAtomicType?)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($nodes-to-change[1]))
  let $_queue :=
    mem-op:queue(
      $transaction-id,
      $nodes-to-change,
      text { $value },
      "replace-value")
  return
    mem-op:execute($transaction-id)
};

(: Queue replacement of a value of an element or attribute :)
declare function mem-op:replace-value(
  $transaction-id as xs:string,
  $nodes-to-change as node()*,
  $value as xs:anyAtomicType?)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id,
    $nodes-to-change,
    text { $value },
    "replace-value")
};

(: Replaces contents of an element :)
declare function mem-op:replace-contents(
  $nodes-to-change as node()+,
  $contents as node()*)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($nodes-to-change[1]))
  let $_queue :=
    mem-op:queue(
      $transaction-id,
      $nodes-to-change,
      $contents,
      "replace-value")
  return
    mem-op:execute($transaction-id)

};

(: Queue replacement of contents of an element :)
declare function mem-op:replace-contents(
  $transaction-id as xs:string,
  $nodes-to-change as node()*,
  $contents as node()*)
as empty-sequence()
{
  mem-op:queue(
    $transaction-id,
    $nodes-to-change,
    $contents,
    "replace-value")
};

(: Replaces with the result of the passed function :)
declare function mem-op:transform(
  $nodes-to-change as node()+,
  $transform-function as function(node()) as node()*)
as node()?
{
  let $transaction-id := mem-op:copy(fn:root($nodes-to-change[1]))
  let $_queue := mem-op:transform(
          $transaction-id,
          $nodes-to-change,
          $transform-function)
  return (
     mem-op:execute($transaction-id)
   )
};

(: Queues the replacement of the node with the result of the passed function :)
declare function mem-op:transform(
  $transaction-id as xs:string,
  $nodes-to-change as node()*,
  $transform-function as function(node()) as node()*)
as empty-sequence()
{
   let $function-key as xs:string := mem-op:function-key($transform-function)
   return
  (map:put(
     map:get($queue, $transaction-id), $function-key, $transform-function),
   mem-op:queue(
     $transaction-id,
     $nodes-to-change,
     text { $function-key },
     "transform"))
};

(: Select the root to return after transaction :)
declare function mem-op:copy($node-to-copy as node())
as xs:string
{
  let $transaction-id as xs:string := concat(mem-op:generate-id($node-to-copy), current-dateTime())
  let $transaction-map as map:map := map:map()
  let $_add-copy-to-transaction-map as empty-sequence() := map:put($transaction-map, "copy", $node-to-copy)
  let $_add-transaction-map-to-queue as empty-sequence() := map:put(
                                                            $queue,
                                                            $transaction-id,
                                                            $transaction-map
                                                           )
  return $transaction-id
};

(: Execute transaction :)
declare function mem-op:execute($transaction-id as xs:string)
as node()*
{
  let $transaction-map := map:get($queue, $transaction-id)
  let $root := fn:head(
      (
        map:get($transaction-map, "copy"), 
        fn:root(map:get($transaction-map, "nodes-to-modify")[1])
      )
    )
  let $results := 
    xdmp:xslt-invoke(
      'transform.xslt',
      $root,
      map:entry('transaction-map',$transaction-map)
    )
  return (
    if ($root instance of document-node()) then
      $results
    else
      $results/node(),
    map:delete($queue, $transaction-id),
    map:clear($transaction-map)
  )
};

(: Execute transaction :)
declare function mem-op:execute-section($transaction-id as xs:string, $section-root as node())
as node()*
{
  let $transaction-map as map:map := map:get($queue, $transaction-id),
      $nodes-to-mod as node()* := map:get($transaction-map, "nodes-to-modify") intersect ($section-root/descendant-or-self::node(),$section-root/descendant-or-self::*/@*)
  let $root := $section-root
  let $results := 
    xdmp:xslt-invoke(
      'transform.xslt',
      $root,
      map:entry('transaction-map',$transaction-map)
    )
  return
    if ($root instance of document-node()) then
      $results
    else
      $results/node()
};

(: Begin private functions! :)

(: Queue actions for later execution :)
declare %private
function mem-op:queue(
  $transaction-id as xs:string,
  $nodes-to-modify as node()*,
  $modifier-nodes as node()*,
  $operation as xs:string?)
as empty-sequence()
{
  if (exists($nodes-to-modify))
  then
    let $transaction-map as map:map := map:get($queue, $transaction-id)
    (: Creates elements based off of generate-id (i.e., node is 12439f8e4a3, then we get back <mem-op:_12439f8e4a3/>) :)
    let $modified-node-ids as element()* := mem-op:id-wrapper($nodes-to-modify) (: This line uses function mapping :)
    return
    (
    mem-op:all-nodes-from-same-doc($nodes-to-modify,map:get($transaction-map,"copy")),
    map:put(
        $transaction-map,
        "operation",
        (<mem-op:operation>{
             attribute operation { $operation },
             $modified-node-ids
           }</mem-op:operation>,
         (: Ensure operations are accummulated :)
         map:get($transaction-map, "operation"))),
    map:put(
        $transaction-map,
        "nodes-to-modify",
        ($nodes-to-modify,
         (: Ensure nodes to modify are accummulated :)
         map:get($transaction-map, "nodes-to-modify"))),
    map:put(
        $transaction-map,
        "modifier-nodes",
        (<mem-op:modifier-nodes>{
             attribute mem-op:operation { $operation },
             $modifier-nodes[self::attribute()],
             $modified-node-ids,
             $modifier-nodes[not(self::attribute())]
           }</mem-op:modifier-nodes>,
         (: Ensure nodes to modifier nodes are accummulated :)
         map:get($transaction-map, "modifier-nodes")))
    )
  else ()
};

declare function mem-op:all-nodes-from-same-doc($nodes as node()*,$parent-node as node()) as empty-sequence() {
  (: NOTE: must use every in satisfies to account for multiple outermost nodes :)
  if (every $n in node-op:outermost(($parent-node,$nodes)) satisfies $n is $parent-node)
  then ()
  else
    error(xs:QName("mem-op:MIXEDSOURCES"), "The nodes to change are coming from multiple sources",$nodes)
};

(: Generate an id unique to a node in memory. Right now using fn:generate-id. :)
declare
function mem-op:id-wrapper($node as node())
{
  element {mem-op:generate-id-qn($node)} {()}
};

(: Generate QName from node :)
declare
function mem-op:generate-id-qn($node as node())
{
  QName(
      "http://maxdewpoint.blogspot.com/memory-operations",
      concat("_", mem-op:generate-id($node)))
};

(: Generate an id unique to a node in memory. Right now using fn:generate-id. :)
declare %private
function mem-op:generate-id($node as node())
{
  generate-id($node)
};

(: Create a key to uniquely identify a function :)
declare
function mem-op:function-key($function as function(*))
{
    xdmp:key-from-QName(
      (function-name($function),
       xs:QName("_" || string(xdmp:random())))[1]) ||
    "#" ||
    string(function-arity($function))
};

declare function mem-op:run-transform(
  $transaction-map as map:map?,
  $mod-nodes,
  $node
) {
  if (exists($transaction-map))
  then
    map:get(
      $transaction-map,
      string($mod-nodes))(
      $node)
  else
    map:get($transform-functions, string($mod-nodes))(
      $node)
};