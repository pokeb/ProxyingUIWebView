//
//  HTMLParser.m
//  TextTransfer
//
//  Created by Ben Copsey on 29/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

#import "HTMLParser.h"
#import "ASIHTTPRequest.h"
#import "CSSParser.h"
#import <libxml/HTMLparser.h>
#import <libxml/xmlsave.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

// I have disabled fetching audio and video content for this example
//static xmlChar *xpathExpr = (xmlChar *)"//head|//link/@href|//a/@href|//script/@src|//img/@src|//frame/@src|//iframe/@src|//style|//*/@style|//source/@src|//video/@poster|//audio/@src";

static xmlChar *xpathExpr = (xmlChar *)"//head|//link/@href|//a/@href|//script/@src|//img/@src|//frame/@src|//iframe/@src|//style|//*/@style";

@implementation HTMLParser

+ (BOOL)parseDataForRequest:(ASIHTTPRequest *)request error:(NSError **)error
{
	NSStringEncoding encoding = [request responseEncoding];
	NSString *string = [[NSString alloc] initWithContentsOfFile:[request downloadDestinationPath] usedEncoding:&encoding error:NULL];
	[string release];
	NSURL *baseURL = [request url];
	
    xmlInitParser();
	xmlDocPtr doc;
	if ([request downloadDestinationPath]) {
		doc = htmlReadFile([[request downloadDestinationPath] cStringUsingEncoding:NSUTF8StringEncoding], [self encodingNameForStringEncoding:encoding], HTML_PARSE_RECOVER | HTML_PARSE_NONET | HTML_PARSE_NOWARNING | HTML_PARSE_NOERROR);
	} else {
		NSData *data = [request responseData];
		doc = htmlReadMemory([data bytes], (int)[data length], "", [self encodingNameForStringEncoding:encoding], HTML_PARSE_RECOVER | HTML_PARSE_NONET | HTML_PARSE_NOWARNING | HTML_PARSE_NOERROR);
	}
    if (doc == NULL) {
		[super parseDataForRequest:request error:error];
		return YES;
    }
	
	// Create xpath evaluation context
    xmlXPathContextPtr xpathCtx = xmlXPathNewContext(doc);
    if(xpathCtx == NULL) {
		if (error) {
			*error = [NSError errorWithDomain:NetworkRequestErrorDomain code:101 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Error: unable to create new XPath context",NSLocalizedDescriptionKey,nil]];
		}
		return NO;
    }
	
    // Evaluate xpath expression
    xmlXPathObjectPtr xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    if(xpathObj == NULL) {
        xmlXPathFreeContext(xpathCtx); 
		if (error) {
			*error = [NSError errorWithDomain:NetworkRequestErrorDomain code:101 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Error: unable to evaluate XPath expression!",NSLocalizedDescriptionKey,nil]];
		}
		return NO;
    }
	
	// Now loop through our matches
	xmlNodeSetPtr nodes = xpathObj->nodesetval;
	
    int size = (nodes) ? nodes->nodeNr : 0;
	int i;
    for(i = size - 1; i >= 0; i--) {
		assert(nodes->nodeTab[i]);
		NSString *parentName  = [NSString stringWithCString:(char *)nodes->nodeTab[i]->parent->name encoding:encoding];
		NSString *nodeName = [NSString stringWithCString:(char *)nodes->nodeTab[i]->name encoding:encoding];
		
		xmlChar *nodeValue = xmlNodeGetContent(nodes->nodeTab[i]);
		NSString *value = [NSString stringWithCString:(char *)nodeValue encoding:encoding];
		xmlFree(nodeValue);
		
		// Here we add a <base> element to the header to make the end result play better with javascript
		// (UIWebView seemed to ignore the Content-Base http header when I tried)
		if ([[nodeName lowercaseString] isEqualToString:@"head"]) {
			
			xmlNodePtr node = xmlNewNode(NULL, (xmlChar *)"base");
			
			xmlNewProp(node, (xmlChar *)"href", (xmlChar *)[[baseURL absoluteString] cStringUsingEncoding:encoding]);
			
			node = xmlDocCopyNode(node, doc, 1);
			xmlAddChild(nodes->nodeTab[i], node);

		// Our xpath query matched all <link> elements, but we're only interested in stylesheets
		// We do the work here rather than in the xPath query because the query is case-sensitive, and we want to match on 'stylesheet', 'StyleSHEEt' etc
		} else if ([[parentName lowercaseString] isEqualToString:@"link"]) {
			xmlChar *relAttribute = xmlGetNoNsProp(nodes->nodeTab[i]->parent,(xmlChar *)"rel");
			if (relAttribute) {
				NSString *rel = [NSString stringWithCString:(char *)relAttribute encoding:encoding];
				xmlFree(relAttribute);
				if ([[rel lowercaseString] isEqualToString:@"stylesheet"] || [[rel lowercaseString] isEqualToString:@"alternate stylesheet"]) {
					xmlNodeSetContent(nodes->nodeTab[i], (xmlChar *)[[self localURLForURL:value withBaseURL:baseURL] cStringUsingEncoding:encoding]);

				}
			}
			
		// Parse the content of <style> tags and style attributes to find external image urls or external css files
		} else if ([[nodeName lowercaseString] isEqualToString:@"style"]) {
			
			xmlNodeSetContent(nodes->nodeTab[i], (xmlChar *)[[CSSParser replaceURLsInCSSString:value withBaseURL:baseURL] cStringUsingEncoding:encoding]);
			
		// Parse the content of <source src=""> tags (HTML 5 audio + video)
		// We explictly disable the download of files with .webm, .ogv and .ogg extensions, since it's highly likely they won't be useful to us
		} else if ([[parentName lowercaseString] isEqualToString:@"source"] || [[parentName lowercaseString] isEqualToString:@"audio"]) {
			NSString *fileExtension = [[value pathExtension] lowercaseString];
			if (![fileExtension isEqualToString:@"ogg"] && ![fileExtension isEqualToString:@"ogv"] && ![fileExtension isEqualToString:@"webm"]) {
				xmlNodeSetContent(nodes->nodeTab[i], (xmlChar *)[[self localURLForURL:value withBaseURL:baseURL] cStringUsingEncoding:encoding]);

			}
			
			// For all other elements matched by our xpath query (except hyperlinks), add the content as an external url to fetch
		} else if (![[parentName lowercaseString] isEqualToString:@"a"]) {
			xmlNodeSetContent(nodes->nodeTab[i], (xmlChar *)[[self localURLForURL:value withBaseURL:baseURL] cStringUsingEncoding:encoding]);

		}
		if (nodes->nodeTab[i]->type != XML_NAMESPACE_DECL) {
			nodes->nodeTab[i] = NULL;
		}
    }
	
	xmlXPathFreeObject(xpathObj);
    xmlXPathFreeContext(xpathCtx); 
	
		
	// We'll use the xmlsave API so we can strip the xml declaration
	xmlSaveCtxtPtr saveContext;

	
	if ([request downloadDestinationPath]) {
			
		// Truncate the file first
		NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
		
		[fileManager createFileAtPath:[request downloadDestinationPath] contents:nil attributes:nil];
		
		saveContext = xmlSaveToFd([[NSFileHandle fileHandleForWritingAtPath:[request downloadDestinationPath]] fileDescriptor],[self encodingNameForStringEncoding:NSUTF8StringEncoding],2|8); // 2 == XML_SAVE_NO_DECL, this isn't declared on Mac OS 10.5
		xmlSaveDoc(saveContext, doc);
		xmlSaveClose(saveContext);
		
	} else {
		#if TARGET_OS_MAC && MAC_OS_X_VERSION_MAX_ALLOWED <= __MAC_10_5
		// xmlSaveToBuffer() is not implemented in the 10.5 version of libxml
		NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
		[[[[NSFileManager alloc] init] autorelease] createFileAtPath:tempPath contents:nil attributes:nil];
		saveContext = xmlSaveToFd([[NSFileHandle fileHandleForWritingAtPath:tempPath] fileDescriptor],[self encodingNameForStringEncoding:NSUTF8StringEncoding],2|8); // 2 == XML_SAVE_NO_DECL, this isn't declared on Mac OS 10.5
		xmlSaveDoc(saveContext, doc);
		xmlSaveClose(saveContext);
		[request setRawResponseData:[NSMutableData dataWithContentsOfFile:tempPath]];
		#else
		xmlBufferPtr buffer = xmlBufferCreate();
		saveContext = xmlSaveToBuffer(buffer,[self encodingNameForStringEncoding:NSUTF8StringEncoding],2|8); // 2 == XML_SAVE_NO_DECL, this isn't declared on Mac OS 10.5
		xmlSaveDoc(saveContext, doc);
		xmlSaveClose(saveContext);
		[request setRawResponseData:[[[NSMutableData alloc] initWithBytes:buffer->content length:buffer->use] autorelease]];
		xmlBufferFree(buffer);
		#endif
		
	}
	NSString *contentType = [[[request responseHeaders] objectForKey:@"Content-Type"] lowercaseString];
	contentType = [[contentType componentsSeparatedByString:@";"] objectAtIndex:0];
	if (!contentType) {
		contentType = @"text/html";
	}
	
	[[request responseHeaders] setValue:[NSString stringWithFormat:@"%@; charset=utf-8"] forKey:@"Content-Type"];
	[request setResponseEncoding:NSUTF8StringEncoding];
	xmlFreeDoc(doc);
	doc = nil;
	
	[super parseDataForRequest:request error:error];
	return YES;
}


+ (const char *)encodingNameForStringEncoding:(NSStringEncoding)theEncoding
{
	xmlCharEncoding encoding = XML_CHAR_ENCODING_NONE;
	switch (theEncoding)
	{
		case NSASCIIStringEncoding:
			encoding = XML_CHAR_ENCODING_ASCII;
			break;
		case NSJapaneseEUCStringEncoding:
			encoding = XML_CHAR_ENCODING_EUC_JP;
			break;
		case NSUTF8StringEncoding:
			encoding = XML_CHAR_ENCODING_UTF8;
			break;
		case NSISOLatin1StringEncoding:
			encoding = XML_CHAR_ENCODING_8859_1;
			break;
		case NSShiftJISStringEncoding:
			encoding = XML_CHAR_ENCODING_SHIFT_JIS;
			break;
		case NSISOLatin2StringEncoding:
			encoding = XML_CHAR_ENCODING_8859_2;
			break;
		case NSISO2022JPStringEncoding:
			encoding = XML_CHAR_ENCODING_2022_JP;
			break;
		case NSUTF16BigEndianStringEncoding:
			encoding = XML_CHAR_ENCODING_UTF16BE;
			break;
		case NSUTF16LittleEndianStringEncoding:
			encoding = XML_CHAR_ENCODING_UTF16LE;
			break;
		case NSUTF32BigEndianStringEncoding:
			encoding = XML_CHAR_ENCODING_UCS4BE;
			break;
		case NSUTF32LittleEndianStringEncoding:
			encoding = XML_CHAR_ENCODING_UCS4LE;
			break;
		case NSNEXTSTEPStringEncoding:
		case NSSymbolStringEncoding:
		case NSNonLossyASCIIStringEncoding:
		case NSUnicodeStringEncoding:
		case NSMacOSRomanStringEncoding:
		case NSUTF32StringEncoding:
		default:
			encoding = XML_CHAR_ENCODING_ERROR;
			break;
	}
	return xmlGetCharEncodingName(encoding);
}


@end
