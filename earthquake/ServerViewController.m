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
    
    self.outputText.editable     = NO;
    self.selectedDir.delegate    = self;
    
    NSString* server_dir = [[NSUserDefaults standardUserDefaults] objectForKey:@"server_dir"];
    if (!server_dir)
        server_dir = [NSString stringWithFormat:@"%@/Downloads", NSHomeDirectory()];
    
    self.selectedDir.stringValue = server_dir;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:NSApp];
    
    
}

// notify the daemon terminated
- (void) serverDidTerminate:(NSNotification *)notification {
    
    //this notification is also called when subprocessed are terminated
    //first, check that we are notified abou the main server process
    NSLog(@"ServerViewController serverDidTerminate");
    int pid = ((NSTask*)notification.object).processIdentifier;
    if (self.task.processIdentifier != pid) return;
    
    NSLog(@"Server ended pid = %d", pid);
    self.task = nil;
    [self.startStopButton setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
    [self addTextToOuput:@"\n+++ terminated +++\n"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                          name:NSFileHandleDataAvailableNotification
                                          object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSTaskDidTerminateNotification
                                                  object:nil];
    
    
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
        
        //task will be set to nil in serverDidterminate: notification
        
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
    [openDlg beginWithCompletionHandler:^(NSInteger result){
        
        if (result == NSFileHandlingPanelOKButton) {

            NSAssert([[openDlg URLs ]count] == 1, @"User can only select one file");
            NSURL* file = [[openDlg URLs] objectAtIndex:0];
            NSLog(@"Selected : %@", file);
            
            // Do something with the folder name
            [self.selectedDir setStringValue:[file path]];
            [self.startStopButton setEnabled:YES];
        }
    }];

}

// enable / disable the start/stop button depending on content of "Selected Folder" text field
- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self.startStopButton setEnabled:(self.selectedDir.stringValue.length > 0)];
}

//persist value to preferences
- (void)controlTextDidEndEditing:(NSNotification *)aNotificationNotification {
    NSLog(@"ServerViewController : controlTextDidEndEditing");
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:self.selectedDir.stringValue forKey:@"server_dir"];
    [prefs synchronize];
}

// add output to TextOutput & scroll to the last line
- (void) addTextToOuput:(NSString*)text {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", text]];
        
        [[self.outputText textStorage] appendAttributedString:attr];
        [self.outputText scrollRangeToVisible:NSMakeRange([[self.outputText string] length], 0)];
    });
}

//be sure we terminate the Daemon when quiting the application
- (void)applicationWillTerminate:(NSNotification *)notification {
    
    NSLog(@"ServerViewController applicationWillTerminate");
    if (self.task && self.task.isRunning) {
        
        NSLog(@"Stop Server");
        [self.task terminate];
    }
    
}

@end
