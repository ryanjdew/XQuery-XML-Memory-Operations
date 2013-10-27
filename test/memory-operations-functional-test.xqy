xquery version "1.0-ml";
module namespace test = "http://github.com/robwhitby/xray/test";
import module namespace assert = "http://github.com/robwhitby/xray/assertions" at "/xray/src/assertions.xqy";

import module namespace mem = "http://maxdewpoint.blogspot.com/memory-operations/functional" at "/memory-operations-functional.xqy";

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

declare %test:case function insert-before-and-insert-attribute()
as item()*
{
	let $new-xml := 
	        mem:execute(mem:insert-child(mem:insert-before(mem:copy($test-xml),
						$test-xml/body/div/p[@class eq "p3"],
						element p { attribute class {"testing"}}
					),
					$test-xml/body/div/p[@class eq "p3"], attribute data-testing {"this-is-a-test"})
				)
	return (
	   assert:equal(fn:count($new-xml/body/div/p[@class eq "p3"]), 2),
	   for $p at $pos in $new-xml/body/div/p[@class eq "p3"]
	   return (
		  assert:equal(fn:string(($p/preceding-sibling::node())[fn:last()]/@class), 'testing'),
		  assert:equal(fn:string($p/@data-testing), 'this-is-a-test'),
		  assert:equal(fn:string($p/parent::node()/@id), fn:concat('div',$pos))
	   )
	)
};

declare %test:case function insert-after-and-insert-attribute()
as item()*
{
	let $new-xml := 
	           let $id := mem:copy($test-xml) 
			   return (
				    mem:insert-after($id,
						$test-xml/body/div/p[@class eq "p3"],
						element p { attribute class {"testing"}}
					),
					mem:insert-child($id, $test-xml/body/div/p[@class eq "p3"], attribute data-testing {"this-is-a-test"}),
					mem:execute($id)
				)
	return (
	   assert:equal(fn:count($new-xml/body/div/p[@class eq "p3"]), 2),
	   for $p at $pos in $new-xml/body/div/p[@class eq "p3"]
	   return (
		  assert:equal(fn:string($p/following-sibling::node()[1]/@class), 'testing'),
		  assert:equal(fn:string($p/@data-testing), 'this-is-a-test'),
		  assert:equal(fn:string($p/parent::node()/@id), fn:concat('div',$pos))
	   )
	)
};

declare %test:case function advanced-operation()
as item()*
{
  let $new-xml := 
				let $id := mem:copy($test-xml) 
				return
				(
				mem:replace($id,$test-xml/head/title,element title {"This is so awesome!"}),
				mem:insert-child($id,$test-xml/body/div/p,attribute data-info {"This is also awesome!"}),
				mem:execute($id)	
				)
				
  return (assert:equal(fn:string($new-xml/head/title), "This is so awesome!"),
			for $p in $new-xml/body/div/p
			return assert:equal(fn:string($p/@data-info), "This is also awesome!"))
};

declare %test:case function copy()
as item()*
{
  let $test-xml := document { $test-xml }/html
  let $new-xml := 
				let $id := mem:copy($test-xml) 
				return
				(
				mem:replace($id,$test-xml/head/title,element title {"This is so awesome!"}),
				mem:insert-child($id,$test-xml/body/div/p,attribute data-info {"This is also awesome!"}),
				mem:execute($id)	
				)
  return (assert:equal($new-xml instance of element(html), fn:true()),
			assert:equal(fn:string($new-xml/head/title), "This is so awesome!"),
			for $p in $new-xml/body/div/p
			return assert:equal(fn:string($p/@data-info), "This is also awesome!"))
};

declare %test:case function multiple-operations-on-one-node()
as item()*
{
  let $title := $test-xml/head/title
  let $new-xml := 
				let $id := mem:copy($title) 
				return
				(
				mem:rename($id,$title,fn:QName("","new-title")),
				mem:replace-value($id,$title,"This is so awesome!"),
				mem:execute($id)	
				)
  return (assert:equal($new-xml instance of element(new-title), fn:true()),
			assert:equal(fn:string($new-xml), "This is so awesome!"))
};

(:The following tests must be commented out due to them breaking the current XQuery parser in XRay :)

declare %test:case function transform-function-transaction()
as item()*
{
  let $title := $test-xml/head/title
  let $new-xml := 
				let $id := mem:copy($title) 
				return
				(
				mem:transform($id,$title,function($node as node()) as node()* {element new-title {"This is so awesome!"}}),
				mem:execute($id)	
				)
  return (assert:equal($new-xml instance of element(new-title), fn:true()),
			assert:equal(fn:string($new-xml), "This is so awesome!"))
};
