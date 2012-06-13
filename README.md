# XQuery XML Memory Operations
This module is created to provide an optimized way to perform operations on XML in memory. With heavy use XPath axis, node comparisions, and set operators this library is able to make changes to XML while only reconstructing nodes within the direct path of the nodes being altered. It also provides a way to perform multiple operations, while only reconstructiing the XML tree once.

The goal is to provide a way to bring the functionality of the XQuery Update Facility 1.0 (http://www.w3.org/TR/xquery-update-10/) to MarkLogic.

## Advanced Transaction
By calling mem:queue the following calls to mem operations are stored and not actually executed until mem:execute() is called. This allows the document to be rebuilt only once and increases performance.
An example of this is as follows:
 ```xquery
(mem:queue(),
mem:replace($file/title, element title {"my new title"}),
mem:insert-child($file, attribute new-attribute {"my new attribute"}),
mem:execute())
```

## Other Operations
 ```xquery
(: See http://www.w3.org/TR/xquery-update-10/#id-delete :)
mem:delete($file//comment()),
(: See http://www.w3.org/TR/xquery-update-10/#id-insert :)
mem:insert-after($file/title, element new-sibling-after {"my new sibling element"} ),
mem:insert-before($file/title, element new-sibling-before {"my new sibling element"} ),
mem:insert-child($file, attribute new-attribute {"my new attribute"} ),
mem:insert-child-first($file, attribute new-attribute-2 {"my new attribute"} ),
(: See http://www.w3.org/TR/xquery-update-10/#id-rename :)
mem:rename($file//block, fn:QName('http://www.w3.org/1999/xhtml','p')),
(: See http://www.w3.org/TR/xquery-update-10/#id-replacing-node :)
mem:replace($file/title, element title {"my new title"} ),
(: See http://www.w3.org/TR/xquery-update-10/#id-replacing-node-value :)
mem:replace-value($file/title, "my new title" )
```

