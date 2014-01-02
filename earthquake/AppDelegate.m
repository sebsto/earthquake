//
//  AppDelegate.m
//  earthquake
//
//  Created by Sébastien Stormacq on 01/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "AppDelegate.h"

#define WINDOW_AUTOSAVE_NAME    @"MainWindow"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //enable auto save the window position
    [self.window.windowController setShouldCascadeWindows:NO];
    [self.window setFrameAutosaveName:WINDOW_AUTOSAVE_NAME];
    
    //restore last windo position
    [self.window setFrameFromString:WINDOW_AUTOSAVE_NAME];
}

/*
 * Close the App when the main window closes
 */
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

@end
