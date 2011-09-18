//
//  SimpleBrowserAppDelegate.h
//  SimpleBrowser
//
//  Created by Ben Copsey on 20/08/2011.
//  Copyright 2011 All-Seeing Interactive. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SimpleBrowserViewController;

@interface SimpleBrowserAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet SimpleBrowserViewController *viewController;

@end
