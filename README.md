# XQuery XML Memory Operations
This module is created to provide an optimized way to perform operations on XML in memory. With heavy use XPath axis, node comparisions, and set operators this library is able to make changes to XML while only reconstructing nodes within the direct path of the nodes being altered. It also provides a way to perform multiple operations, while only reconstructiing the XML tree once.

## Advanced Operation
This function takes an input of item()* that matches the following repeating pattern:
 ```xquery
($operation as xs:string,$nodes-to-modify as node()*, fn:QName("","start-modifiers"),$modifier-nodes as node()*, fn:QName("","end-modifiers")
```
An example of this is as follows:
 ```xquery
mem:advanced-operation(('replace', $file/title, fn:QName("","start-modifiers"), element title {"my new title"} ,fn:QName("","end-modifiers"),
									'insert-child', $file, fn:QName("","start-modifiers"), attribute new-attribute {"my new attribute"} ,fn:QName("","end-modifiers")))
```

## Other Operations
 ```xquery
mem:replace($file/title, element title {"my new title"} ),
mem:insert-child($file, attribute new-attribute {"my new attribute"} ),
mem:insert-child-first($file, attribute new-attribute-2 {"my new attribute"} ),
mem:insert-before($file/title, element new-sibling-before {"my new sibling element"} ),
mem:insert-after($file/title, element new-sibling-after {"my new sibling element"} ),
mem:delete($file//comment())
```

