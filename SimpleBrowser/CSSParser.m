//
//  CSSParser.m
//  TextTransfer
//
//  Created by Ben Copsey on 29/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

#import "CSSParser.h"
#import "ASIHTTPRequest.h"

@implementation CSSParser

+ (BOOL)parseDataForRequest:(ASIHTTPRequest *)request error:(NSError **)error
{
	NSURL *baseURL = [request url];
	if ([request downloadDestinationPath]) {
		NSError *err = nil;
		NSString *css = [NSString stringWithContentsOfFile:[request downloadDestinationPath] encoding:[request responseEncoding] error:&err];
		if (!err) {
			[[self replaceURLsInCSSString:css withBaseURL:baseURL] writeToFile:[request downloadDestinationPath] atomically:NO encoding:[request responseEncoding] error:&err];
		}
		if (err) {
			if (error) {
				*error = [NSError errorWithDomain:NetworkRequestErrorDomain code:101 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Failed to write response CSS",NSLocalizedDescriptionKey,nil]];
			}
			return FALSE;
		}
	} else {
		[request setRawResponseData:(NSMutableData *)[[self replaceURLsInCSSString:[request responseString] withBaseURL:baseURL] dataUsingEncoding:[request responseEncoding]]];
	}
	[super parseDataForRequest:request error:error];
	return TRUE;
}

// A quick and dirty way to build a list of external resource urls from a css string
+ (NSString *)replaceURLsInCSSString:(NSString *)string withBaseURL:(NSURL *)baseURL
{
	NSMutableArray *urls = [NSMutableArray array];
	NSScanner *scanner = [NSScanner scannerWithString:string];
	[scanner setCaseSensitive:NO];
	
	// Find urls in the the CSS string
	while (1) {
		NSString *theURL = nil;
		[scanner scanUpToString:@"url(" intoString:NULL];
		[scanner scanString:@"url(" intoString:NULL];
		[scanner scanUpToString:@")" intoString:&theURL];
		if (!theURL) {
			break;
		}
		NSUInteger originalLength = [theURL length];
		
		// Remove any quotes or whitespace around the url
		theURL = [theURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		theURL = [theURL stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
		theURL = [theURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		[urls addObject:[NSDictionary dictionaryWithObjectsAndKeys:theURL,@"url",[NSNumber numberWithInt:[scanner scanLocation]-originalLength], @"location",[NSNumber numberWithInt:originalLength],@"length", nil]];
	}
	NSMutableString *parsedResponse = [[string mutableCopy] autorelease];
	int lengthToAdd = 0;
	
	// Replace urls in the CSS string, taking account of replacements we have already made and adjusting the replacement range accordingly
	for (NSDictionary *url in urls) {
		
		NSString *newURL = [self localURLForURL:[url objectForKey:@"url"] withBaseURL:baseURL];
		
		[parsedResponse replaceCharactersInRange:NSMakeRange([[url objectForKey:@"location"] intValue]+lengthToAdd, [[url objectForKey:@"length"] intValue]) withString:newURL];
		lengthToAdd += ([newURL length]-[[url objectForKey:@"length"] intValue]);

	}
	return parsedResponse;
}


@end
