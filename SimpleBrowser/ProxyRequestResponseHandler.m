//
//  ProxyRequestResponseHandler.m
//  TextTransfer
//
//  Created by Ben Copsey on 24/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

#import "ProxyRequestResponseHandler.h"
#import "HTTPServer.h"
#import "ASIHTTPRequest.h"
#import "HTMLParser.h"
#import "CSSParser.h"
#import "ASIDownloadCache.h"
#import <CommonCrypto/CommonHMAC.h>

static NSArray *htmlMimeTypes = nil;
static NSArray *cssMimeTypes = nil;

@implementation ProxyRequestResponseHandler

+ (void)initialize
{
	if (self == [ProxyRequestResponseHandler class]) {
		htmlMimeTypes =  [[NSArray alloc] initWithObjects:@"text/html",@"text/xhtml",@"text/xhtml+xml",@"application/xhtml+xml", nil];
		cssMimeTypes = [[NSArray alloc] initWithObjects:@"text/css", nil];
	}
}

- (void)dealloc
{
	[body release];
	[realRequest clearDelegatesAndCancel];
	[realRequest release];
	[cacheStream close];
	[cacheStream release];
	[super dealloc];
}

+ (void)load
{
	[HTTPResponseHandler registerHandler:self];
}

+ (BOOL)canHandleRequest:(CFHTTPMessageRef)aRequest method:(NSString *)requestMethod url:(NSURL *)requestURL headerFields:(NSDictionary *)requestHeaderFields
{
	return YES;
}

- (void)startResponse
{
	[self setBody:[NSMutableData data]];
	[body appendData:[(NSData *)CFHTTPMessageCopyBody(request) autorelease]];
	NSString *cLength = [headerFields objectForKey:@"Content-Length"];
	if (cLength) {
		contentLength = strtoull([cLength UTF8String], NULL, 0);
		if ([body length] == contentLength) {
			[self startRequest];
		}
	} else {
		[self startRequest];
	}
}

- (void)startRequest
{
	haveStartedRequest = YES;
	NSArray *parts = [[url absoluteString] componentsSeparatedByString:@"?url="];
	if ([parts count] < 2) {
		[self sendFailureResponse];
		[server closeHandler:self];
		return;
	}
	NSString *realURL = (NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (CFStringRef)[parts objectAtIndex:1],(CFStringRef)@"",kCFStringEncodingUTF8);

	NSURL *theURL = [NSURL URLWithString:realURL];
	[self setRealRequest:[ASIHTTPRequest requestWithURL:theURL]];
	for (NSString *header in headerFields) {
		if ([[header lowercaseString] isEqualToString:@"host"]) {
			[[self realRequest] addRequestHeader:header value:[theURL host]]; 
		} else {
			[[self realRequest] addRequestHeader:header value:[headerFields objectForKey:header]]; 
		}
	}
	
	[[self realRequest] addRequestHeader:@"Cache-Control" value:@"max-age=0"];
	[[self realRequest] addRequestHeader:@"Pragma" value:@"no-cache"];
	[[self realRequest] setAllowCompressedResponse:NO];
	[[self realRequest] setShouldWaitToInflateCompressedResponses:NO];
	[[self realRequest] setShouldRedirect:NO];
	[[self realRequest] appendPostData:[self body]];
	[[self realRequest] setRequestMethod:requestMethod];
	
	if ([[requestMethod uppercaseString] isEqualToString:@"GET"]) {
		[[self realRequest] setDownloadCache:[ASIDownloadCache sharedCache]];
		[[self realRequest] setCacheStoragePolicy:ASICachePermanentlyCacheStoragePolicy];

		[[self realRequest] setCachePolicy:ASIAskServerIfModifiedWhenStaleCachePolicy|ASIFallbackToCacheIfLoadFailsCachePolicy];
		[[ASIDownloadCache sharedCache] setShouldRespectCacheControlHeaders:NO]; // Force-caching
		[[self realRequest] setDownloadDestinationPath:[[ASIDownloadCache sharedCache] pathToStoreCachedResponseDataForRequest:[self realRequest]]];
	} else {
		[self setupRequestToStoreResponseOutsideCache];
	}
	[[self realRequest] setDelegate:self];
	
	[[self realRequest] startAsynchronous];
}

- (void)setupRequestToStoreResponseOutsideCache
{
	[[self realRequest] setDownloadCache:nil];
	NSString *pathToSave = [[self class] temporaryPathForRequest:[self realRequest]];
	// Truncate the file first
	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
	[fileManager createFileAtPath:pathToSave contents:nil attributes:nil];
	[[self realRequest] setDownloadDestinationPath:pathToSave];
}


- (void)sendResponseHeaders
{
	int responseCode = [[self realRequest] responseStatusCode];
	if (responseCode == 0) {
		[[self realRequest] clearDelegatesAndCancel];
		return;
	}
	
	if ([[self realRequest] downloadCache]) {
		if (responseCode != 200 && responseCode != 301 && responseCode != 302 && responseCode != 303 && responseCode != 307) {
			[self setupRequestToStoreResponseOutsideCache];
		}
	}
	NSString *location = [[[self realRequest] responseHeaders] objectForKey:@"Location"];
	if (location) {
		location = [NSString stringWithFormat:@"http://127.0.0.1:8080?url=%@",[[NSURL URLWithString:location relativeToURL:[[self realRequest] url]] absoluteString]];
		NSMutableDictionary *headers = [[[[self realRequest] responseHeaders] mutableCopy] autorelease];
		[headers setValue:location forKey:@"Location"];
		[[self realRequest] setResponseHeaders:headers];
	}
	
	CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, [[self realRequest] responseStatusCode], NULL, kCFHTTPVersion1_1);
	
	[[[self realRequest] responseHeaders] setValue:[[[self realRequest] url] absoluteString] forKey:@"Content-Base"];
	for (NSString *header in [[self realRequest] responseHeaders]) {
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)header, (CFStringRef)[[[self realRequest] responseHeaders] objectForKey:header]);
	}
	CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Connection", (CFStringRef)@"close");
	[self sendData:[(NSData *)CFHTTPMessageCopySerializedMessage(response) autorelease]];
	CFRelease(response);
}


- (void)sendData:(NSData *)data
{
	@try {
		[fileHandle writeData:data];
	} @catch (NSException *exception) {
		[[self realRequest] clearDelegatesAndCancel];
		[server closeHandler:self];
	}
}

- (void)sendFailureResponse
{
	CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 504, NULL, kCFHTTPVersion1_1);
	CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Connection", (CFStringRef)@"close");
	NSMutableData *data = [NSMutableData dataWithData:[(NSData *)CFHTTPMessageCopySerializedMessage(response) autorelease]];
	[data appendData:[@"The request failed." dataUsingEncoding:NSUTF8StringEncoding]];
	[self sendData:data];
	CFRelease(response);
}


- (NSString *)responseContentType
{
	NSString *contentType = [[[[self realRequest] responseHeaders] objectForKey:@"Content-Type"] lowercaseString];
	return [[contentType componentsSeparatedByString:@";"] objectAtIndex:0];
}

- (void)receiveIncomingDataNotification:(NSNotification *)notification
{
	NSFileHandle *incomingFileHandle = [notification object];
	@try {
		NSData *data = [incomingFileHandle availableData];
		if ([data length] > 0) {
			[body appendData:data];
		}
		[incomingFileHandle waitForDataInBackgroundAndNotify];
		
	} @catch (NSException *exception) {
		[[self realRequest] clearDelegatesAndCancel];
		[server closeHandler:self];

	}
}

- (void)endResponse
{
	if (!haveStartedRequest) {
		haveStartedRequest = YES;
		[self startRequest];
	}
	[super endResponse];
}

- (void)request:(ASIHTTPRequest *)req didReceiveResponseHeaders:(NSDictionary *)responseHeaders
{
	//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		
		NSString *contentType = [self responseContentType];
		if ([htmlMimeTypes indexOfObject:contentType] != NSNotFound || [cssMimeTypes indexOfObject:contentType] != NSNotFound) {
			[self setResponseNeedsParsing:YES];
			return;
		}

		[self sendResponseHeaders];
			
	//});
}

- (void)request:(ASIHTTPRequest *)req didReceiveData:(NSData *)data
{
	//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		if (![req didUseCachedResponse] && [req downloadDestinationPath] && [data length]) {
			if (![self cacheStream]) {
				[self setCacheStream:[NSOutputStream outputStreamToFileAtPath:[req downloadDestinationPath] append:NO]];
				[[self cacheStream] open];
			}
			[[self cacheStream] write:[data bytes] maxLength:[data length]];
		}
		if (![self responseNeedsParsing] && [data length]) {
			[self sendData:data];
		}
	//});
}

- (void)requestFinished:(ASIHTTPRequest *)req
{	
	//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		if ([self cacheStream]) {
			[[self cacheStream] close];
			[self setCacheStream:nil];
		}
		
		if ([self responseNeedsParsing]) {
			NSString *contentType = [self responseContentType];
			NSError *error = nil;
			if ([htmlMimeTypes indexOfObject:contentType] != NSNotFound) {
				if (![HTMLParser parseDataForRequest:req error:&error]) {
					[self sendFailureResponse];
					NSLog(@"Failed to parse HTML from '%@' because '%@'",[req url],error);
					[server closeHandler:self];
					return;
				}
				

			} else if ([cssMimeTypes indexOfObject:contentType] != NSNotFound) {
				if (![CSSParser parseDataForRequest:req error:&error]) {
					[self sendFailureResponse];
					NSLog(@"Failed to parse CSS from '%@' because '%@'",[req url],error);
					[server closeHandler:self];
					return;
				}
			}
			// Write the headers back to the download cache to update the content length
			NSString *headerPath = [[ASIDownloadCache sharedCache] pathToStoreCachedResponseHeadersForRequest:req];
			[[req responseHeaders] writeToFile:headerPath atomically:NO];
		}
		
		if ([self responseNeedsParsing] || [[self realRequest] didUseCachedResponse]) {
			[self sendResponseHeaders];
			if ([req downloadDestinationPath]) {
				NSInputStream *stream = [[[NSInputStream alloc] initWithFileAtPath:[req downloadDestinationPath]] autorelease];
				[stream open];
				while ([stream hasBytesAvailable]) {
					uint8_t buf[32768];
					NSInteger readLength = [stream read:buf maxLength:32768];
					[self sendData:[NSData dataWithBytes:buf length:readLength]];
				}
				[stream close];
			} else {
				[self sendData:[req rawResponseData]];
			}
		}
		[req setDelegate:nil];
		[server closeHandler:self];
	//});
}


- (void)requestFailed:(ASIHTTPRequest *)req
{
	//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self sendFailureResponse];
		NSLog(@"The url '%@' failed to load because '%@'",[req url],[req error]);
		[server closeHandler:self];
	//});
}


+ (NSString *)temporaryPathForRequest:(ASIHTTPRequest *)theRequest
{
	// Borrowed from: http://stackoverflow.com/questions/652300/using-md5-hash-on-a-string-in-cocoa
	const char *cStr = [[[theRequest url] absoluteString] UTF8String];
	unsigned char result[16];
	CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
	NSString *md5 = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],result[8], result[9], result[10], result[11],result[12], result[13], result[14], result[15]]; 	
	return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:md5];
	
}

@synthesize body;
@synthesize responseNeedsParsing;
@synthesize realRequest;
@synthesize cacheStream;
@end
