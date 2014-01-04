//
//  ClientViewController.m
//  earthquake
//
//  Created by Sébastien Stormacq on 03/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "ClientViewController.h"
#import "AppDelegate.h"

@implementation ClientViewController

// TODO : add a panel for extra settings
// server port number
// current (working) directory
// UDP block size
// free text for any command


-(void)awakeFromNib {
    
    self.startStopButton.enabled = NO;
    self.outputText.editable     = NO;
    self.serverAddress.delegate  = self;
    
}

- (IBAction)handleConnectButton:(id)sender {
    if (self.task && self.task.isRunning) {
        
        NSLog(@"Stop Client");
        [self.task terminate];
        
    } else {
        NSLog(@"Start Client");
        
        self.outputText.string = @"";
        [self addTextToOuput:@"+++ started +++"];
        
        [self performSelectorInBackground:@selector(startTsunamiClient) withObject:self];
        self.startStopButton.title = @"Disconnect";
    }
}

// start Tsunami client and register notifications
- (void)startTsunamiClient {
    
    @try {
        
        //get application binary's path
        AppDelegate* delegate = (AppDelegate*)[NSApp delegate];
        NSString* binaryDirectory = [delegate applicationBinaryDirectory];
        NSString* binaryPath = [NSString stringWithFormat:@"%@/tsunami", binaryDirectory];
        
        //App Delegate ensures this binary is valid (exist and correct checksum) at application startup time
        
        // Set up the process
        self.task = [[NSTask alloc] init];
        self.task.launchPath = binaryPath;
        
        // TODO pick up value from settings
        self.task.currentDirectoryPath = @"/Users/stormacq/Downloads";
        
        self.task.arguments = [NSArray arrayWithObjects:@"connect", self.serverAddress.stringValue, nil];
        
        // Set the pipe to the standard output and error to get the results of the command
        NSPipe *p = [[NSPipe alloc] init];
        self.task.standardOutput = p;
        self.task.standardError  = p;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientOutputNotification:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:p.fileHandleForReading];
        
        //this requires to be called from a thread with an active event loop
        [p.fileHandleForReading waitForDataInBackgroundAndNotify];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientDidTerminate:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:nil];
        [self.task launch];
        [self.task waitUntilExit];
    }
    @catch (NSException *exception) {
        self.outputText.string = [exception description];
    }
    @finally {
        self.startStopButton.title = @"Connect";
        self.task = nil;
    }
    
}

// notify the client terminated
- (void) clientDidTerminate:(NSNotification *)notification {
    NSLog(@"client ended");
    
    self.startStopButton.title = @"Connect";
    self.task = nil;
    [self addTextToOuput:@"+++ terminated +++"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

// notify the client produced text output
- (void)clientOutputNotification:(NSNotification *)notification
{
    NSLog(@"client OutputNotification");
    NSData *data = nil;
    NSFileHandle* file = (NSFileHandle*)notification.object;
    
    while ((data = [file availableData]) && [data length]){
        
        [self addTextToOuput:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        
        [file waitForDataInBackgroundAndNotify];
    }
}

- (IBAction)handleSettingsButton:(id)sender {
}
// enable / disable the start/stop button depending on content of "Server Address" text field
- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self.startStopButton setEnabled:(self.serverAddress.stringValue.length > 0)];
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
