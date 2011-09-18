//
//  CSSParser.h
//  TextTransfer
//
//  Created by Ben Copsey on 29/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

//
//  This parser replaces urls in the content of a stylesheet or other set of CSS declarations 
//  (eg style tags or style attributes)
//

#import <Foundation/Foundation.h>
#import "ContentParser.h"

@interface CSSParser : ContentParser

+ (NSString *)replaceURLsInCSSString:(NSString *)string withBaseURL:(NSURL *)baseURL;


@end
