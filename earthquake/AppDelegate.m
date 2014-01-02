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

//check if Tsunami binaries are available and download them if required
-(void) checkAndDownloadBinaries {
    
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

    NSString* tsunamiClientPath = [NSString stringWithFormat:@"%@/tsunami", binaryDirectory];
    NSString* tsunamiServerPath = [NSString stringWithFormat:@"%@/tsunamid", binaryDirectory];
    
    const NSString* tsunamiClientDownloadURL = @"http://tsunami-udp.s3.amazonaws.com/v1.1%20devel%20gitbuild%2044/Darwin_13.0.0/tsunami";
    const NSString* tsunamiServerDownloadURL = @"http://tsunami-udp.s3.amazonaws.com/v1.1%20devel%20gitbuild%2044/Darwin_13.0.0/tsunamid";
    
    const NSString* tsunamiClientMD5 = @"20ef359579e7821ba8f99ef265e89fc9";
    const NSString* tsunamiClientSHA = @"f766f3f97516cfe884ae2965d501c8769f1ce226";

    const NSString* tsunamiServerMD5 = @"68ac0a9aa6f2fd5fb0d0ace846abb9f2";
    const NSString* tsunamiServerSHA = @"db13dae7fd2536f3791c6a0d54014028a4a7e48d";
    
    // TODO : create a separate method for this
    NSLog(@"Checking Client : %@", tsunamiClientPath);
    // TODO : check MD5 and SHA of existing file
    if ( ! [fm fileExistsAtPath:tsunamiClientPath]) {
        NSLog(@"Downloading Tsunami Client Binary");
        
        //file is small enough to load all content in NSData
        NSURL* url = [NSURL URLWithString:(NSString*)tsunamiClientDownloadURL];
        NSData* client = [NSData dataWithContentsOfURL:url];
        
        if ( [[[client sha1HexHash] lowercaseString] isEqualToString:(NSString*)tsunamiClientSHA] &&
             [[[client md5HexHash] lowercaseString] isEqualToString:(NSString*)tsunamiClientMD5]) {
            
            
            NSLog(@"Writing Client's data to file");
            [client writeToFile:(NSString*)tsunamiClientPath options:NSDataWritingAtomic error:&error];
            
            if (error) {
                NSLog(@"Error while writing to %@", tsunamiClientPath);
                
                // TODO : report error to user
            }
            
            // TODO : change permission to 755
        } else {
            NSLog(@"Checksum do not match");
            
            // TODO : report error to user
        }
    }

    NSLog(@"Checking Server : %@", tsunamiServerPath);
    // TODO : check MD5 and SHA of existing file
    if ( ! [fm fileExistsAtPath:tsunamiServerPath]) {
        NSLog(@"Downloading Tsunami Server Binary");
        
        //file is small enough to load all content in NSData
        NSURL* url = [NSURL URLWithString:(NSString*)tsunamiServerDownloadURL];
        NSData* server = [NSData dataWithContentsOfURL:url];
        
        if ( [[[server sha1HexHash] lowercaseString] isEqualToString:(NSString*)tsunamiServerSHA] &&
             [[[server md5HexHash] lowercaseString] isEqualToString:(NSString*)tsunamiServerMD5]) {
            
            
            NSLog(@"Writing Server's data to file");
            [server writeToFile:(NSString*)tsunamiServerPath options:NSDataWritingAtomic error:&error];
            
            if (error) {
                NSLog(@"Error while writing to %@", tsunamiServerPath);
                
                // TODO : report error to user
            }
            
            // TODO : change permission to 755
            
        } else {
            NSLog(@"Checksum do not match");
            
            // TODO : report error to user
        }
    }

    
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //check if Tsunami binaries are available and download them if required
    [self checkAndDownloadBinaries];

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
