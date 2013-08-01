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

module namespace node-op = "http://maxdewpoint.blogspot.com/node-operations";
declare default function namespace "http://www.w3.org/2005/xpath-functions";


declare function node-op:innermost($nodes as node()*) {
	(: node-op:function-select((
		function-lookup(QName('http://www.w3.org/2005/xpath-functions','innermost'), 1),
		function ($nodes as node()*) { :)
			$nodes except $nodes/ancestor::node()
	(:	}
	))($nodes) :)
};

declare function node-op:outermost($nodes as node()*) {
	(:node-op:function-select((
		function-lookup(QName('http://www.w3.org/2005/xpath-functions','outermost'), 1),
		function ($nodes as node()*) { :)
			$nodes except ($nodes/descendant::node(),$nodes/descendant-or-self::node()/attribute::node())
	(:	}
	))($nodes) :)
};

declare function node-op:inbetween($nodes as node()*, $start as node()?, $end as node()?) {
	node-op:inbetween($nodes, $start, $end, ())
};

declare function node-op:inbetween-inclusive($nodes as node()*, $start as node()?, $end as node()?) {
	node-op:inbetween($nodes, $start, $end, ('start','end'))
};

declare function node-op:inbetween-inclusive-start($nodes as node()*, $start as node()?, $end as node()?) {
	node-op:inbetween($nodes, $start, $end, ('start'))
};

declare function node-op:inbetween-inclusive-end($nodes as node()*, $start as node()?, $end as node()?) {
	node-op:inbetween($nodes, $start, $end, ('end'))
};

declare %private function node-op:inbetween($nodes as node()*, $start as node()?, $end as node()?, $inclusion as xs:string*) {
	(
	   if ($inclusion = 'start')
	   then $nodes intersect $start
	   else ()
	) union (
	   if (exists($start) and exists($end))
	   then $nodes[. >> $start][. << $end]
	   else if (exists($start))
	   then $nodes[. >> $start]
	   else if (exists($end))
	   then $nodes[. << $end]
	   else ()
	) union (
	   if ($inclusion = 'end')
	   then $nodes intersect $end
	   else ()
	)
};



declare %private function node-op:function-select($functions as function(*)+) as function(*) {
	$functions[1]
};