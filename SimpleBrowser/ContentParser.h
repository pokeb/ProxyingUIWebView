//
//  ContentParser.h
//  TextTransfer
//
//  Created by Ben Copsey on 29/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.

//
//  The base class for parsers that modify content
//

#import <Foundation/Foundation.h>

@class ASIHTTPRequest;

@interface ContentParser : NSObject

+ (BOOL)parseDataForRequest:(ASIHTTPRequest *)request error:(NSError **)error;
+ (NSString *)localURLForURL:(NSString *)url withBaseURL:(NSURL *)baseURL;

@end
