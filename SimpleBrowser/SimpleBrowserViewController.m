//
//  SimpleBrowserViewController.m
//  SimpleBrowser
//
//  Created by Ben Copsey on 20/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

#import "SimpleBrowserViewController.h"
#import "ASIDownloadCache.h"
#import "ContentParser.h"
#import "HTTPServer.h"

@implementation SimpleBrowserViewController

- (void)viewDidLoad
{
	[[HTTPServer sharedHTTPServer] start];
	[super viewDidLoad];
}

- (IBAction)openURL:(id)sender
{
	[urlBar resignFirstResponder];
	NSURL *url = [NSURL URLWithString:[urlBar text]];
	if (![url scheme]) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@",[urlBar text]]];
	}
	if (!url) {
		return;
	}
	[self loadURL:url];
}

- (void)loadURL:(NSURL *)url
{
	NSURL *newURL = [NSURL URLWithString:[ContentParser localURLForURL:[url absoluteString] withBaseURL:nil]];
	[webView loadRequest:[NSURLRequest requestWithURL:newURL]];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv
{
	NSArray *parts = [[[[wv request] URL] absoluteString] componentsSeparatedByString:@"?url="];
	if ([parts count] > 1) {
		NSString *realURL = (NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (CFStringRef)[parts objectAtIndex:1],(CFStringRef)@"",kCFStringEncodingUTF8);
		[urlBar setText:realURL];
	}
}

// We'll take over the page load when the user clicks on a link
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)theRequest navigationType:(UIWebViewNavigationType)navigationType
{
	if (![[[theRequest URL] scheme] isEqualToString:@"http"] && ![[[theRequest URL] scheme] isEqualToString:@"https"]) {
		return YES;
	}
	if (navigationType == UIWebViewNavigationTypeLinkClicked || navigationType == UIWebViewNavigationTypeFormSubmitted || navigationType == UIWebViewNavigationTypeFormResubmitted) {
		if ([[[[theRequest URL] absoluteURL] host] isEqualToString:@"127.0.0.1"]) {
			return YES;
		}
		[urlBar setText:[[theRequest URL] absoluteString]];
		[self loadURL:[theRequest URL]];		
		return NO;
	}
	
	// Other request types are often things like iframe content, we have no choice but to let UIWebView load them itself
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[self openURL:nil];
	return NO;
}


- (IBAction)historyBack:(id)sender
{
	[webView goBack];
}
- (IBAction)historyForward:(id)sender
{
	[webView goForward];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

@end
