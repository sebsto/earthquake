//
//  AppDelegate.m
//  earthquake
//
//  Created by Sébastien Stormacq on 01/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "AppDelegate.h"
#import "NSData+CryptoHash.h"

#define WINDOW_AUTOSAVE_NAME    @"MainWindow"

@implementation AppDelegate

- (void) checkAndDownloadFile:(NSString*)path url:(NSString*)downloadURL md5:(NSString*)md5 sha:(NSString*)sha {

    NSError *error;
    NSFileManager* fm = [NSFileManager defaultManager];

    NSLog(@"Checking File at %@", path);
    
    if ( ! [fm fileExistsAtPath:path]) {
        NSLog(@"Downloading file at %@", downloadURL);
        
        //file is small enough to load all content in NSData
        NSURL* url = [NSURL URLWithString:downloadURL];
        NSData* data = [NSData dataWithContentsOfURL:url];
        
        if ( [[[data sha1HexHash] lowercaseString] isEqualToString:sha] &&
            [[[data md5HexHash] lowercaseString] isEqualToString:md5]) {
            
            
            NSLog(@"Writing data to file");
            [data writeToFile:path options:NSDataWritingAtomic error:&error];
            
            if (error) {
                NSLog(@"Error while writing to %@", path);
                
                NSAlert* alert = [[NSAlert alloc] init];
                alert.alertStyle = NSCriticalAlertStyle;
                alert.messageText = @"Fatal Error";
                alert.informativeText = [NSString stringWithFormat:@"Can not write to %@\n\nThis error is not supposed to happen, please report it at https://github.com/sebsto/earthquake/issues", path];
                alert.icon = [NSImage imageNamed:@"NSImageNameCaution"];
                [alert runModal];
                
                [NSApp terminate:self];
                
            }
            
            //493 is decimal for 755 octal (rwxr-xr-x)
            [fm setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:493]
                                                          forKey:NSFilePosixPermissions]
                 ofItemAtPath:path
                        error:&error];
        } else {
            NSLog(@"Checksum do not match");
            
            NSAlert* alert = [[NSAlert alloc] init];
            alert.alertStyle = NSCriticalAlertStyle;
            alert.messageText = @"Fatal Error";
            alert.informativeText = [NSString stringWithFormat:@"Invalid content downloaded from %@\n\nThis error is not supposed to happen, please report it at https://github.com/sebsto/earthquake/issues", downloadURL];
            alert.icon = [NSImage imageNamed:@"NSImageNameCaution"];
            [alert runModal];
            
            [NSApp terminate:self];
        }
    } else {
        
        NSLog(@"File at %@ already exists", path);

        //file exist - ensure checksums are OK
        NSData* data = [NSData dataWithContentsOfFile:path];
        if ( ! [[[data sha1HexHash] lowercaseString] isEqualToString:sha] ||
             ! [[[data md5HexHash] lowercaseString] isEqualToString:md5]) {
            
            NSLog(@"Checksum do not match");

            NSAlert* alert = [[NSAlert alloc] init];
            alert.alertStyle = NSCriticalAlertStyle;
            alert.messageText = @"Fatal Error";
            alert.informativeText = [NSString stringWithFormat:@"Invalid content at %@\n\nTry to delete this file and start again", path];
            alert.icon = [NSImage imageNamed:@"NSImageNameCaution"];
            [alert runModal];

            [NSApp terminate:self];
        }
    }
}

//return the directory where TSunami binaries will be installed
-(NSString*) applicationBinaryDirectory {

    NSError *error;
    
    NSURL *appSupportDir = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                  inDomain:NSUserDomainMask
                                                         appropriateForURL:nil
                                                                    create:YES
                                                                     error:&error];
    NSString* bundleID = [NSBundle mainBundle].bundleIdentifier;
    
    NSString* binaryDirectory   = [NSString stringWithFormat:@"%@/%@", [appSupportDir path], bundleID];
    
    NSFileManager* fm = [NSFileManager defaultManager];
    
    // create binary directory if it does not exist
    NSLog(@"Checking existence of %@", binaryDirectory);
    if ( ! [fm fileExistsAtPath:binaryDirectory]) {
        
        NSLog(@"Creating directory for binaries");
        [fm createDirectoryAtPath:binaryDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        
    }
    
    return binaryDirectory;
    
}

//check if Tsunami binaries are available and download them if required
-(void) checkAndDownloadBinaries {
    
    
    NSString* binaryDirectory = [self applicationBinaryDirectory];

    NSString* tsunamiClientPath = [NSString stringWithFormat:@"%@/tsunami", binaryDirectory];
    NSString* tsunamiServerPath = [NSString stringWithFormat:@"%@/tsunamid", binaryDirectory];
    
    const NSString* tsunamiClientDownloadURL = @"http://tsunami-udp.s3.amazonaws.com/v1.1%20devel%20gitbuild%2044/Darwin_13.0.0/tsunami";
    const NSString* tsunamiServerDownloadURL = @"http://tsunami-udp.s3.amazonaws.com/v1.1%20devel%20gitbuild%2044/Darwin_13.0.0/tsunamid";
    
    const NSString* tsunamiClientMD5 = @"20ef359579e7821ba8f99ef265e89fc9";
    const NSString* tsunamiClientSHA = @"f766f3f97516cfe884ae2965d501c8769f1ce226";

    const NSString* tsunamiServerMD5 = @"68ac0a9aa6f2fd5fb0d0ace846abb9f2";
    const NSString* tsunamiServerSHA = @"db13dae7fd2536f3791c6a0d54014028a4a7e48d";
    
    [self checkAndDownloadFile:tsunamiClientPath
                           url:(NSString*)tsunamiClientDownloadURL
                           md5:(NSString*)tsunamiClientMD5
                           sha:(NSString*)tsunamiClientSHA];
    
    [self checkAndDownloadFile:tsunamiServerPath
                           url:(NSString*)tsunamiServerDownloadURL
                           md5:(NSString*)tsunamiServerMD5
                           sha:(NSString*)tsunamiServerSHA];
    
}

//TODO : application's main window briefly flashes when the method below terminates the app due to an error
- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    //check if Tsunami binaries are available and download them as required
    [self checkAndDownloadBinaries];
}

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
