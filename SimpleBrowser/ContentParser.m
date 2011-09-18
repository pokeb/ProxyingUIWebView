//
//  ContentParser.m
//  TextTransfer
//
//  Created by Ben Copsey on 29/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

#import "ContentParser.h"
#import "ASIHTTPRequest.h"

@implementation ContentParser

+ (NSString *)localURLForURL:(NSString *)url withBaseURL:(NSURL *)baseURL
{
	NSURL *theURL = [NSURL URLWithString:url relativeToURL:baseURL];
	NSString *scheme = [[theURL scheme] lowercaseString];
	if (scheme && ![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
		return url;
	}
	url = [theURL absoluteString];
	url = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)url,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8);
	NSString *newURL =  [NSString stringWithFormat:@"http://127.0.0.1:8080?url=%@",url];
	return newURL;
}

+ (BOOL)parseDataForRequest:(ASIHTTPRequest *)request error:(NSError **)error
{
	NSUInteger contentLength = 0;
	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
	if ([request downloadDestinationPath]) {
		contentLength = [[fileManager attributesOfItemAtPath:[request downloadDestinationPath] error:NULL] fileSize];
	} else {
		contentLength = [[request rawResponseData] length];
	}
	// If the data was originally deflated, by now we have already inflated it, so we remove the content-encoding header
	NSMutableDictionary *headers = [[[request responseHeaders] mutableCopy] autorelease];
	if ([request isResponseCompressed]) {
		[headers removeObjectForKey:@"Content-Encoding"];
	}
	// Adds a content length header if one wasn't already included
	if (contentLength > 0) {
		[headers setValue:[NSString stringWithFormat:@"%lu",contentLength] forKey:@"Content-Length"];
	}
	[request setResponseHeaders:headers];
	return TRUE;
}

@end
