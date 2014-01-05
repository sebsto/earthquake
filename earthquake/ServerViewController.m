//
//  Server.m
//  earthquake
//
//  Created by Sébastien Stormacq on 02/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "ServerViewController.h"

#import "AppDelegate.h"

@implementation ServerViewController

// setup default value after loading
- (void)awakeFromNib {
    
    self.startStopButton.enabled = NO;
    self.outputText.editable     = NO;
    self.selectedDir.delegate    = self;
    
}

// notify the daemon terminated
- (void) serverDidTerminate:(NSNotification *)notification {
    
    //this notification is also called when subprocessed are terminated
    //first, check that we are notified abou the main server process
    int pid = ((NSTask*)notification.object).processIdentifier;
    if (self.task.processIdentifier != pid) return;
    
    NSLog(@"Server ended pid = %d", pid);
    self.task = nil;
    [self.startStopButton setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
    [self addTextToOuput:@"\n+++ terminated +++\n"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

// notify the daemon produced text output
- (void)serverOutputNotification:(NSNotification *)notification
{
    NSLog(@"Server OutputNotification");
    NSData *data = nil;
    NSFileHandle* file = (NSFileHandle*)notification.object;
    
    while ((data = [file availableData]) && [data length]){
        
        [self addTextToOuput:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        
        [file waitForDataInBackgroundAndNotify];
    }
}

// handle click on start / stop button
- (IBAction)controlTsunamiDaemon:(id)sender {
    
    if (self.task && self.task.isRunning) {
        
        NSLog(@"Stop Server");
        [self.task terminate];
        
    } else {
        NSLog(@"Start Server");
        
        self.outputText.string = @"";
        [self addTextToOuput:@"+++ started +++\n"];
        
        [self performSelectorInBackground:@selector(startDaemon) withObject:self];
        [self.startStopButton setImage:[NSImage imageNamed:@"NSStopProgressTemplate"]];
    }
}

// start daemon and register notifications
- (void)startDaemon {
    
    @try {
        
        //get application binary's path
        AppDelegate* delegate = (AppDelegate*)[NSApp delegate];
        NSString* binaryDirectory = [delegate applicationBinaryDirectory];
        NSString* binaryPath = [NSString stringWithFormat:@"%@/tsunamid", binaryDirectory];
        
        //App Delegate ensures this binary is valid (exist and correct checksum) at application startup time

        // Set up the process
        self.task = [[NSTask alloc] init];
        self.task.launchPath = binaryPath;
        self.task.currentDirectoryPath = self.selectedDir.stringValue;
        
        self.task.arguments = [[NSFileManager defaultManager]
                                    contentsOfDirectoryAtPath:self.selectedDir.stringValue
                                    error:nil];
        
        // Set the pipe to the standard output and error to get the results of the command
        NSPipe *p = [[NSPipe alloc] init];
        self.task.standardOutput = p;
        self.task.standardError  = p;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(serverOutputNotification:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:p.fileHandleForReading];
        
        //this requires to be called from a thread with an active event loop
        [p.fileHandleForReading waitForDataInBackgroundAndNotify];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(serverDidTerminate:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:nil];
        [self.task launch];
        NSLog(@"Server launched, pid = %d", self.task.processIdentifier);
        
        [self.task waitUntilExit];
    }
    @catch (NSException *exception) {
        self.outputText.string = [exception description];
    }
    @finally {
        [self.startStopButton setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
        self.task = nil;
    }

}

// handle "Select Folder" button
- (IBAction)selectFolder:(id)sender {

    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];

    // Enable the selection of directories in the dialog.
    [openDlg setCanChooseDirectories:YES];
    [openDlg setCanChooseFiles:NO];
    [openDlg setAllowsMultipleSelection:NO];
    
    // Display the dialog box.  If the OK pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton ) {

        // Gets list of all files selected
        NSArray *files = [openDlg URLs];
        
        // Loop through the folder and process them (should be only one)
        NSAssert([files count] == 1, @"More than one folder selected !");
        for( int i = 0; i < [files count]; i++ ) {
            // Do something with the folder name
            [self.selectedDir setStringValue:[[files objectAtIndex:i] path]];
            [self.startStopButton setEnabled:YES];
            
        }
    }

}

// enable / disable the start/stop button depending on content of "Selected Folder" text field
- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self.startStopButton setEnabled:(self.selectedDir.stringValue.length > 0)];
}

// add output to TextOutput & scroll to the last line
- (void) addTextToOuput:(NSString*)text {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", text]];
        
        [[self.outputText textStorage] appendAttributedString:attr];
        [self.outputText scrollRangeToVisible:NSMakeRange([[self.outputText string] length], 0)];
    });
}

@end
