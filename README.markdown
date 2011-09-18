# Proxying UIWebView - EXPERIMENTAL!

###What?
This project demonstrates a UIWebView that proxies nearly all HTTP requests via a local web-server.

###Why?
This is a replacement for my [ASIWebPageRequest class](http://allseeing-i.com/ASIHTTPRequest/ASIWebPageRequest), currently part of [ASIHTTPRequest](http://allseeing-i.com/ASIHTTPRequest). ASIWebPageRequest started with a root web page, parsed it to find the urls of external resources, then downloaded and cached each one. When the process was finished, you could take the locally cached content and display it in the webview.

This allowed you to, for example:

* Cache large web pages, including external resources, indefinitely on disk
* Use ASIHTTPRequest features like throttling, custom proxies etc for content loaded in a UIWebView
* With some tweaking you could potentially load different content for external resources

This project demonstrates a different approach to the same problem. In this project, requests made by the UIWebView are sent to a local mini-webserver that downloads the remote content and returns it to the webview.

###Advantages over ASIWebPageRequest
* This approach is _MUCH_ faster, partly because the WebView can begin rendering the page before it has completely loaded, but also because only the resources needed to display the page are downloaded
* This approach works better with javascript because the base url of the content is changed to mimic the original web page
* Though the overall class structure is a bit more complex, it should be easier to customise

###How it works
1. SimpleBrowserViewController reads the url from the address bar, then changes it to point at the local webserver. For example, a request to http://allseeing-i.com becomes http://127.0.0.1:8080/url?=http://allseeing-i.com.
2. The webserver receives the request, the forwards it on to the real destination. ASIHTTPRequest is currently used to create these requests, but with a bit of tweaking it should be easy to use NSURLConnection instead.
3. When we start to receive the response from the remote server, we look at the content type. If it looks like the content is either HTML or CSS, we wait to receive the whole thing. Otherwise, we start returning the content to the webview unmodified.
4. When we finish receiving an HTML or CSS document, we parse the contents to replace urls pointing at the remote server with urls pointing at our local webserver. Once replacement is complete, we return the content to the webview.

The sample is setup to store content permanently with ASIDownloadCache for demonstration purposes. You can change this or customise the requests in other ways by modifying startRequest in ProxyRequestResponseHandler.m.


###Known issues
* Not all requests are proxied via the local webserver. In particular, content loaded via javascript is loaded by the WebView directly.
* Some sites don't work properly at present. For example, m.youtube.com doesn't work at all, and pages on apple.com have significant rendering artifacts. In general, it works well with sites built with well-formed, standards compliant markup that don't make heavy use of JS, and less well with other sites.
* This project includes a slightly tweaked version of ASIHTTPRequest, but I haven't got around to documenting these changes or moving them into the main ASIHTTTPRequest distribution.
* Libxml can get shouty in your console when it finds HTML it doesn't like

###Areas for improvement
* The webserver and parsing operations currently run on the main thread. It should be fairly straightforward to move these into a background thread.
* Currently only works on iOS. It should be possible to use the same approach with the WebView class on Mac.

-- 

###IMPORTANT
This was written over a couple of weekends, and should be considered *experimental*. The code could use some cleanup. It doesn't work with all web content, and though it should be more widely compatible than ASIWebPageRequest, [many of the same limitations apply](http://allseeing-i.com/ASIHTTPRequest/ASIWebPageRequest#limitations). You should not consider this to be a drop-in replacement for UIWebView's regular loading mechanism - it will work best with pages you have tested and confirmed to work (it might be ideal for caching content created specifically for your app offline, for example).

###Acknowledgements
All the hard work of handling requests from the webview is done by a slightly tweaked version of [Matt Gallagher's simple Cocoa webserver](http://cocoawithlove.com/2009/07/simple-extensible-http-server-in-cocoa.html).

HTML content is parsed using [libxml](http://xmlsoft.org/). If you want to use Libxml in a Mac or iOS project, make sure you add the dylib and add this to your _Header Search Paths_ in Xcode:

    ${SDK_DIR}/usr/include/libxml2

