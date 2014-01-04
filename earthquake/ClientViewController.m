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
    self.serverAddress.target    = self;
    self.serverAddress.action    = @selector(handleConnectButton:);
    
    self.state  = NEXT_STEP_NONE;
    self.buffer = nil;
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
        NSPipe *pout = [[NSPipe alloc] init];
        self.task.standardOutput = pout;
        self.task.standardError  = pout;
        
        // Set another pipe to write to standard input
        NSPipe* pin = [[NSPipe alloc] init];
        self.task.standardInput = pin;
        self.input = pin.fileHandleForWriting;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientOutputNotification:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:pout.fileHandleForReading];
        
        //this requires to be called from a thread with an active event loop
        [pout.fileHandleForReading waitForDataInBackgroundAndNotify];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientDidTerminate:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:nil];
        [self.task launch];
        
        //Initial fetch list of available files (will be received in clientOutputNotification method)
        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(queue, ^{
            NSLog(@"Going to execute DIR command");
            self.state = NEXT_STEP_DIR;
            [self.input writeData:[@"dir\n" dataUsingEncoding:NSUTF8StringEncoding]];
        });
        
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
    self.task   = nil;
    self.buffer = nil;
    [self addTextToOuput:@"+++ terminated +++"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

//once every output line for the DIR command have been gathered, parse them
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
        if (string.length == 0) break;
        //NSLog(@"Handling line[%d] : %@", i, string);
        
        struct file_item item;
        
        
        //first number - not used - use array index instead
        /*
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\ [0-9]+"
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
    
    if (self.state == NEXT_STEP_DIR && [line hasPrefix:@"Remote file list:"]) {
        
        //we are going to receive the list of file at next call
        self.state = NEXT_STEP_REMOTE_FILE_LIST;
        NSLog(@"+++ Remote File List +++");
        
    } else if (self.state == NEXT_STEP_REMOTE_FILE_LIST) {
        
        //receiving list of available available files, store them as table data source
        NSLog(@"+++ File List +++");
        if (!self.buffer) self.buffer = [[NSMutableArray alloc] init];
        [self.buffer addObject:line];
        
        if ([line rangeOfString:@"tsunami>"].location != NSNotFound) {
            
            //we have received the complete file list - no more next step
            self.state = NEXT_STEP_NONE;
            NSLog(@"+++ File list is complete");
            
            [self parseFileList];
        }
        
    }

    //NSLog(@"%@", line);

}


// notify the client produced text output
- (void)clientOutputNotification:(NSNotification *)notification
{
    NSLog(@"client OutputNotification");
    NSData *data = nil;
    NSFileHandle* file = (NSFileHandle*)notification.object;
    
    //NSMutableString* buffer = [[NSMutableString alloc] init];
    
    while ((data = [file availableData]) && [data length]){
        
        NSString* line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        //[buffer appendString:line];
        [self handleOutputLine:line];
        [self addTextToOuput:line];
        
        //[file waitForDataInBackgroundAndNotify];
    }
    
    //[self handleOutputLine:buffer];
    //[self addTextToOuput:buffer];

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
