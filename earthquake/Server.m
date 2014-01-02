//
//  Server.m
//  earthquake
//
//  Created by Sébastien Stormacq on 02/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "Server.h"

@implementation Server

// setup default value after loading
- (void)awakeFromNib {
    
    self.startStopButton.enabled = NO;
    [self.outputText setEditable:NO];
    self.selectedDir.delegate = self;
    
}

// notify the daemon terminated
- (void) commandDidTerminate:(NSNotification *)notification {
    NSLog(@"daemon ended");
    self.task = nil;
    
    [self addTextToOuput:@"+++ terminated +++"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

// notify the daemon produced text output
- (void)commandOutputNotification:(NSNotification *)notification
{
    NSLog(@"commandOutputNotification");
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
        
        NSLog(@"Stop Task");
        [self.task terminate];
        
    } else {
        NSLog(@"Start Task");
        
        self.outputText.string = @"";
        [self addTextToOuput:@"+++ started +++"];
        
        [self performSelectorInBackground:@selector(startDaemon) withObject:self];
        [self.startStopButton setImage:[NSImage imageNamed:@"NSStopProgressTemplate"]];
    }
}

// start daemon and register notifications
- (void)startDaemon {
    
    @try {

        // Set up the process
        self.task = [[NSTask alloc] init];
        self.task.launchPath = @"/Users/stormacq/Downloads/tsunamid";
        self.task.currentDirectoryPath = self.selectedDir.stringValue;
        
        self.task.arguments = [[NSFileManager defaultManager]
                                    contentsOfDirectoryAtPath:self.selectedDir.stringValue
                                    error:nil];
        
        // Set the pipe to the standard output and error to get the results of the command
        NSPipe *p = [[NSPipe alloc] init];
        self.task.standardOutput = p;
        self.task.standardError  = p;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(commandOutputNotification:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:p.fileHandleForReading];
        
        //this requires to be called from a thread with an active event loop
        [p.fileHandleForReading waitForDataInBackgroundAndNotify];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(commandDidTerminate:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:nil];
        [self.task launch];
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
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", text]];
        
        [[self.outputText textStorage] appendAttributedString:attr];
        [self.outputText scrollRangeToVisible:NSMakeRange([[self.outputText string] length], 0)];
    });
}

@end
