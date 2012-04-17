xquery version "1.0-ml";
module namespace test = "http://github.com/robwhitby/xray/test";
import module namespace assert = "http://github.com/robwhitby/xray/assertions" at "/xray/src/assertions.xqy";

import module namespace mem = "http://maxdewpoint.blogspot.com/memory-operations" at "/memory-operations.xqy";

declare variable $test-xml := <html>
								<head>
									<title>This is a title</title>
								</head>
								<!-- old comment -->
								<body>
									<div id="div1">
										<p class="p1"><!-- old comment -->This is a paragraph.</p>
										<p class="p2">This is a paragraph.</p>
										<p class="p3">This is a paragraph.</p>
										<p class="p4">This is a paragraph.</p>
										<p class="p5">This is a paragraph.</p>
									</div>
									<div id="div2">
										<p class="p1">This is a paragraph.</p>
										<p class="p2">This is a paragraph.</p>
										<p class="p3">This is a paragraph.<!-- old comment --></p>
										<p class="p4">This is a paragraph.</p>
										<p class="p5">This is a paragraph.</p>
									</div>
								</body>
							</html>;


declare function insert-child-into-root-attribute()
as item()*
{
	let $new-xml := mem:insert-child(
						$test-xml,
						attribute test {"testing"}
					)
	return assert:equal(fn:string($new-xml/@test), 'testing')	
};

declare function insert-child-into-many-items-attribute()
as item()*
{
	let $new-xml := mem:insert-child(
						($test-xml,$test-xml/body/div[@id eq "div1"],
						$test-xml/body/div/p),
						attribute test {"testing"}
					)
	for $i in ($new-xml,$new-xml/body/div[@id eq "div1"],
						$new-xml/body/div/p)
	return assert:equal(fn:string($i/@test), 'testing')	
};

declare function insert-child-into-root-element()
as item()*
{
	let $new-xml := mem:insert-child(
						$test-xml,
						element test {"testing"}
					)
	return assert:equal(fn:string($new-xml/test), 'testing')	
};

declare function insert-child-into-many-items-element()
as item()*
{
	let $new-xml := mem:insert-child(
						($test-xml,$test-xml/body/div[@id eq "div1"],
						$test-xml/body/div/p),
						element test {"testing"}
					)
	for $i in ($new-xml,$new-xml/body/div[@id eq "div1"],
						$new-xml/body/div/p)
	return assert:equal(fn:string($i/test), 'testing')	
};

declare function insert-before()
as item()*
{
	let $new-xml := mem:insert-before(
						$test-xml/body/div/p[@class eq "p3"],
						element p { attribute class {"testing"}}
					)
	for $p in $new-xml/div/p[@class eq "p3"]
	return 
		assert:equal(fn:string($p/preceding-sibling::node()[fn:last()]/@class), 'testing')	
};

declare function insert-after()
as item()*
{
	let $new-xml := mem:insert-after(
						$test-xml/body/div/p[@class eq "p3"],
						element p { attribute class {"testing"}}
					)
	for $p in $new-xml/body/div/p[@class eq "p3"]
	return 
		assert:equal(fn:string($p/following-sibling::node()[1]/@class), 'testing')	
};

declare function remove-items()
as item()*
{
   let $new-xml := mem:delete(
						$test-xml//comment()
					)
	return (assert:equal(fn:count($test-xml//comment()) gt 0, fn:true()),
			assert:equal(fn:count($new-xml//comment()), 0))
};

declare function replace-items()
as item()*
{
   let $new-xml := mem:replace(
						$test-xml//comment(),
						<!--this new comment-->
					)
	return (assert:equal(fn:count($new-xml//comment()), fn:count($test-xml//comment())),
			for $c in $new-xml//comment()
			return assert:equal(fn:string($c), 'this new comment'))
};

declare function replace-attributes()
as item()*
{
   let $new-xml := mem:replace(
						$test-xml//p/@class,
						attribute class {"new-class"}
					)
	return (assert:equal(fn:count($new-xml//p/@class), fn:count($test-xml//p/@class)),
			for $c in $new-xml//p/@class
			return assert:equal(fn:string($c), 'new-class'))
};

declare function advanced-operation()
as item()*
{
  let $start-mod-qname := fn:QName("","start-modifiers"),
      $end-mod-qname := fn:QName("","end-modifiers"), 
      $new-xml := mem:advanced-operation(("replace",$test-xml/head/title,$start-mod-qname,element title {"This is so awesome!"},$end-mod-qname,
                                      "insert-child",$test-xml/body/div/p,$start-mod-qname,attribute data-info {"This is also awesome!"},$end-mod-qname))
  return (assert:equal(fn:string($new-xml/head/title), "This is so awesome!"),
			for $p in $new-xml/body/div/p
			return assert:equal(fn:string($p/@data-info), "This is also awesome!"))
};