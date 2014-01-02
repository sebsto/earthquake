//
//  Server.m
//  Hearthquake
//
//  Created by Sébastien Stormacq on 02/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "Server.h"

@implementation Server

- (void)awakeFromNib {
    
    self.startStopButton.enabled = NO;
    [self.outputText setEditable:NO];
    self.selectedDir.delegate = self;
    
}

- (void) commandDidTerminate:(NSNotification *)notification {
    NSLog(@"daemon ended");
    [self.task terminate];
    self.task = nil;
    
}

- (void)commandOutputNotification:(NSNotification *)notification
{
    NSLog(@"commandOutputNotification");
    NSData *data = nil;
    NSFileHandle* file = (NSFileHandle*)notification.object;
    
    while ((data = [file availableData]) && [data length]){
        
        NSString *outStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        self.outputText.string = [self.outputText.string stringByAppendingString:
                                                   [NSString stringWithFormat:@"%@", outStr]];
        
        // Scroll to end of outputText field
        NSRange range;
        range = NSMakeRange(self.outputText.string.length, 0);
        [self.outputText scrollRangeToVisible:range];
        
        [file waitForDataInBackgroundAndNotify];
    }
}

- (IBAction)controlTsunamiDaemon:(id)sender {
    
    if (self.task && self.task.isRunning) {
        NSLog(@"Stop Task");
        [self.task terminate];
    } else {
        NSLog(@"Start Task");
        self.outputText.string = @"";
        [self performSelectorInBackground:@selector(startDaemon) withObject:self];
        [self.startStopButton setImage:[NSImage imageNamed:@"NSStopProgressTemplate"]];
    }
}

- (void)startDaemon {
    
    @try {

        // Set up the process
        self.task = [[NSTask alloc] init];
        self.task.launchPath = @"/Users/stormacq/Downloads/tsunamid";
        self.task.currentDirectoryPath = self.selectedDir.stringValue;
        //self.task.arguments = [NSArray arrayWithObjects:@"*", nil];
        
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

- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self.startStopButton setEnabled:(self.selectedDir.stringValue.length > 0)];
}

@end
