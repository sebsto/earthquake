//
//  AppDelegate.h
//  earthquake
//
//  Created by Sébastien Stormacq on 01/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

//return the directory where TSunami binaries will be installed
-(NSString*) applicationBinaryDirectory;

@end
