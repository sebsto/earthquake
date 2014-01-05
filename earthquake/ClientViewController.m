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


// TODO : crash when server is not available

#pragma mark Initialization

-(void)awakeFromNib {
    
    self.startStopButton.enabled = NO;
    self.outputText.editable     = NO;
    
    self.serverAddress.delegate  = self;
    self.serverAddress.target    = self;
    self.serverAddress.action    = @selector(handleConnectButton:);
    
    self.state  = NEXT_STEP_UNKNOWN;
    self.buffer = nil;
    
    self.commandQueue = [[NSMutableArray alloc] init];
}

#pragma mark send command to client

-(void)dequeueCommand:(NSNotification *)notification {

    NSString* cmd = (NSString*)[self.commandQueue lastObject];
    
    if (self.state != NEXT_STEP_READY) {
        NSLog(@"Client is not ready for sending command");
        return;
    }
    if (!cmd) {
        NSLog(@"no command available to dequeue");
        return;
    }
    
    [self.commandQueue removeLastObject];
    
    NSLog(@"Going to execute '%@' command", cmd);
    NSString* command = [NSString stringWithFormat:@"%@\n",cmd ];
    [self addTextToOuput:command];
    [self.input writeData:[command dataUsingEncoding:NSUTF8StringEncoding]];

    //warn other methods of this class that we are expecting a file list
    if ([cmd isEqualToString:@"dir"]) self.state = NEXT_STEP_DIR;
}

-(void)sendCommand:(NSString*)cmd {
    
    //queue command for later execution
    [self.commandQueue insertObject:cmd atIndex:0];
    
    //commands will be dequeued when the 'tsunami> ' prompt will appear
    
    //when client is in READY state - go ahead and dequeue command immediatley
    if (self.state == NEXT_STEP_READY) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_CLIENT_READY object:self];
    }
    
    
}

#pragma mark Start / Stop Client

- (IBAction)handleConnectButton:(id)sender {
    if (self.task && self.task.isRunning) {
        
        NSLog(@"Stop Client");
        //[self.task terminate];
        [self sendCommand:@"close"];
        
    } else {
        NSLog(@"Start Client");
        
        self.outputText.string = @"";
        [self addTextToOuput:@"+++ started +++\n"];
        
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
        NSPipe *pout = [[NSPipe alloc] init];
        self.task.standardOutput = pout;
        self.task.standardError  = pout;
        
        // Set another pipe to write to standard input
        NSPipe* pin = [[NSPipe alloc] init];
        self.task.standardInput = pin;
        self.input = pin.fileHandleForWriting;
        
        //register for "output available" notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientOutputNotification:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:pout.fileHandleForReading];
        
        //this requires to be called from a thread with an active event loop
        [pout.fileHandleForReading waitForDataInBackgroundAndNotify];
        
        //register for "client terminated" notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientDidTerminate:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:nil];
        //register for "client ready" notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(dequeueCommand:)
                                                     name:NOTIFICATION_CLIENT_READY
                                                   object:nil];

        [self.task launch];

        //enqueue command
        [self sendCommand:@"dir"];
        
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

#pragma mark Output Parsing

//once each output line for the DIR command has been gathered, parse them
//to create an array with (filename, size)
- (NSArray*) parseFileList {
    
    NSMutableArray* result = [[NSMutableArray alloc] init];
    
    // re-assemble partial lines into one big string delimited by \n
    NSMutableString* temp = [[NSMutableString alloc] init];
    for (int i = 0; i < self.buffer.count ; i++) {
        [temp appendString:[self.buffer objectAtIndex:i]];
    }
    
    // and split that string into lines
    // each line has the following format
    // " 15) play-2.2.2-RC1.zip                                              112902441 bytes"
    //
    // '\ [0-9]+'                   gives the leading number
    // '([a-zA-Z].*\\ )(?=[0-9])'   gives the file name         TODO : this regexp assumes file names start with a letter
    // '(\\ [0-9]+)'                second match gives the file size
    
    
    NSArray* lines = [temp componentsSeparatedByString:@"\n"]; //TODO : does this works on Windows ?
    
    //do not use the last line ("tsunami>" prompt)
    for (int i = 0; i < lines.count - 1 ; i++ ) {
        
        NSError* error;
        NSString* string = [lines objectAtIndex:i];
        
        //skip empty lines
        if (string.length == 0) break;
        //NSLog(@"Handling line[%d] : %@", i, string);
        
        struct file_item item;
        
        
        //first number - not used - use array index instead
        /*
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\ [0-9]+"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:&error];
        NSRange rangeOfFirstMatch = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
        if (!NSEqualRanges(rangeOfFirstMatch, NSMakeRange(NSNotFound, 0))) {
            NSString *substringForFirstMatch = [[string substringWithRange:rangeOfFirstMatch] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
            //NSLog(@"Item Number ===%@===", substringForFirstMatch);
        }
        */
        
        
        //file name (assuming file name starts with a letter)
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"([a-zA-Z].*\\ )(?=[0-9])"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        NSRange rangeOfFirstMatch = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
        if (!NSEqualRanges(rangeOfFirstMatch, NSMakeRange(NSNotFound, 0))) {
            item.name = [[string substringWithRange:rangeOfFirstMatch] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
            //NSLog(@"File Name ===%@===", item.name);
        }
        
        
        //file size
        regex = [NSRegularExpression regularExpressionWithPattern:@"(\\ [0-9]+)"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        NSRange rangeofSecondMatch = ((NSTextCheckingResult*)[[regex matchesInString:string options:0 range:NSMakeRange(0, [string length])] objectAtIndex:1]).range;
        if (!NSEqualRanges(rangeofSecondMatch, NSMakeRange(NSNotFound, 0))) {
            item.size = (NSUInteger)[[[string substringWithRange:rangeofSecondMatch] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] longLongValue];
            //NSLog(@"File Size : %ld", item.size);
        }
        
        [result insertObject:[NSValue valueWithPointer:&item] atIndex:i];

    }
    
    return result;
}

//statefull method to handle client's output
-(void)handleOutputLine:(NSString*)line {
    
    // TODO must parse error message when the client can not connect
    
    if ([line hasSuffix:@"tsunami> "]) {
        self.state = NEXT_STEP_READY;
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_CLIENT_READY object:self];
    }
    
    if (self.state == NEXT_STEP_DIR && [line hasPrefix:@"Remote file list:"]) {
        
        //we are going to receive the list of file at next call
        self.state = NEXT_STEP_REMOTE_FILE_LIST;
        //NSLog(@"+++ Remote File List +++");
        
    } else if (self.state == NEXT_STEP_REMOTE_FILE_LIST) {
        
        //receiving list of available available files, store them as table data source
        //NSLog(@"+++ File List +++");
        if (!self.buffer) self.buffer = [[NSMutableArray alloc] init];
        [self.buffer addObject:line];
        
        if ([line hasSuffix:@"tsunami> "]) {
            
            //we have received the complete file list - no more next step
            //NSLog(@"+++ File list is complete");
            [self performSelectorInBackground:@selector(parseFileList) withObject:self];
        }
        
    }

    //NSLog(@"---%@---", line);

}

#pragma mark Notifications

// notify the client produced text output
- (void)clientOutputNotification:(NSNotification *)notification
{
    NSLog(@"client OutputNotification");
    NSData *data = nil;
    NSFileHandle* file = (NSFileHandle*)notification.object;
    
    while ((data = [file availableData]) && [data length]){
        
        NSString* line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        [self handleOutputLine:line];
        [self addTextToOuput:line];
        
    }
    
}

// notify the client terminated
- (void) clientDidTerminate:(NSNotification *)notification {
    NSLog(@"client ended");
    
    self.startStopButton.title = @"Connect";
    self.task   = nil;
    self.buffer = nil;
    [self addTextToOuput:@"\n+++ terminated +++\n"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

#pragma mark Misc

- (IBAction)handleSettingsButton:(id)sender {
}

// enable / disable the start/stop button depending on content of "Server Address" text field
- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self.startStopButton setEnabled:(self.serverAddress.stringValue.length > 0)];
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
