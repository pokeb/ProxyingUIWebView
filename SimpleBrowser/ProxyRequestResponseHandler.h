//
//  ProxyRequestResponseHandler.h
//  TextTransfer
//
//  Created by Ben Copsey on 24/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

//
//  This class reads requests to the local webserver, creates requests to the real webserver, and returns content to the webview
//  It currently uses ASIHTTPRequest to create the 'real' requests, though it ought to be possible to port it to NSURLConnection fairly easily
//

#import "HTTPResponseHandler.h"

@class ASIHTTPRequest;

@interface ProxyRequestResponseHandler : HTTPResponseHandler {
	NSMutableData *body;
	unsigned long long contentLength;
	BOOL responseNeedsParsing;
	ASIHTTPRequest *realRequest;
	NSOutputStream *cacheStream;
	BOOL haveStartedRequest;
}
- (void)startRequest;
- (void)sendFailureResponse;
- (void)sendResponseHeaders;
- (void)sendData:(NSData *)data;
- (NSString *)responseContentType;
- (void)setupRequestToStoreResponseOutsideCache;
+ (NSString *)temporaryPathForRequest:(ASIHTTPRequest *)theRequest;

@property (retain, nonatomic) NSMutableData *body;
@property (assign, nonatomic) BOOL responseNeedsParsing;
@property (retain, nonatomic) ASIHTTPRequest *realRequest;
@property (retain, nonatomic) NSOutputStream *cacheStream;
@end
