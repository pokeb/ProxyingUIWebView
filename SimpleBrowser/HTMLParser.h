//
//  HTMLParser.h
//  TextTransfer
//
//  Created by Ben Copsey on 29/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

// 
// This parser replaces urls in HTML source
// It uses the xpath query (xpathExpr) to find attributes containing remote urls
//

#import <Foundation/Foundation.h>
#import "ContentParser.h"

@class ASIHTTPRequest;

@interface HTMLParser : ContentParser;

+ (const char *)encodingNameForStringEncoding:(NSStringEncoding)encoding;

@end
