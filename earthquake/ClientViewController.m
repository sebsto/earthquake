//
//  ClientViewController.m
//  earthquake
//
//  Created by Sébastien Stormacq on 03/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "ClientViewController.h"
#import "SettingsPanelViewController.h"
#import "AppDelegate.h"

@implementation ClientViewController

#pragma mark Initialization

-(void)awakeFromNib {
    
    self.outputText.editable     = NO;
    
    self.serverAddress.delegate  = self;
    self.serverAddress.target    = self;
    self.serverAddress.action    = @selector(handleConnectButton:);
    
    self.fileTable.dataSource    = self;
    self.fileTable.target        = self;
    self.fileTable.doubleAction  = @selector(doubleClick:);
    
    self.connected          = NO;
    self.state              = kNextStepUnknow;
    self.outputLinesBuffer  = nil;
    self.task               = nil;
    
    self.settingsWindow     = nil;
    
    self.commandQueue = [[NSMutableArray alloc] init];
    
    NSString* server_address = [[NSUserDefaults standardUserDefaults] objectForKey:@"server_address"];
    if (!server_address)
        server_address = @"localhost";
    
    self.serverAddress.stringValue = server_address;
    
}

#pragma mark send command to client

-(void)dequeueCommand:(NSNotification *)notification {

    NSString* cmd = (NSString*)[self.commandQueue lastObject];
    
    if (self.state != kNextStepReady) {
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
    if ([cmd isEqualToString:@"dir"]) self.state = kNextStepDir;
    
    
}

-(void)sendCommand:(NSString*)cmd {
    
    //queue command for later execution
    [self.commandQueue insertObject:cmd atIndex:0];
    
    //commands will be dequeued when the 'tsunami> ' prompt will appear
    
    //when client is in READY state - go ahead and dequeue command immediatley
    if (self.state == kNextStepReady) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationClientReady object:self];
        
        //do not accept other command while not back in READY state
        self.state = kNextStepWait;
    }
    
}

#pragma mark Start / Stop Client

- (IBAction)handleConnectButton:(id)sender {
    
    if (self.task && self.task.isRunning && self.connected) {
        
        NSLog(@"Disconnect Client");
        [self sendCommand:@"close"];
        
    } else {
        
        if (self.task && self.task.isRunning && !self.connected) {
            
            NSLog(@"Reconnect client");
            [self sendCommand:[NSString stringWithFormat:@"connect %@", self.serverAddress.stringValue]];
            
            [self sendCommand:@"dir"];
            
        } else {
            
            NSLog(@"Start Client");
            [self performSelectorInBackground:@selector(startTsunamiClient) withObject:self];

        }
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
        
        self.task.currentDirectoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"client_dir"];        
        //self.task.arguments = [NSArray arrayWithObjects:@"connect", self.serverAddress.stringValue, nil];
        
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
                                                     name:kNotificationClientReady
                                                   object:nil];

        [self.task launch];

        self.outputText.string = @"";
        [self addTextToOuput:@"+++ started +++\n"];
        self.statusButton.image = [NSImage imageNamed:@"NSStatusAvailable"];
        
        NSString* serverPort = [[NSUserDefaults standardUserDefaults] objectForKey:@"server_port"];
        if (!serverPort) serverPort = @"46224";
        
        //enqueue command
        [self sendCommand:[NSString stringWithFormat:@"set port %@", serverPort]];
        [self sendCommand:[NSString stringWithFormat:@"connect %@", self.serverAddress.stringValue]];
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
    for (int i = 0; i < self.outputLinesBuffer.count ; i++) {
        [temp appendString:[self.outputLinesBuffer objectAtIndex:i]];
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
        
        //wrap my struct to NSData to store it in an NSArray
        //I am not using NSValue because it does not copy the bits, just wrap the pointer
        //which is released at the end of this method
        NSData *data = [NSData dataWithBytes:&item length:sizeof(item)];
        [result insertObject:data atIndex:i];

    }
    
    return result;
}

//statefull method to handle client's output
-(void)handleOutputLine:(NSString*)line {
    
    // TODO must parse error message when the client can not connect
    //NSLog(@"---%@---", line);

    if ([line rangeOfString:@"Connection closed."].location != NSNotFound) {
        self.startStopButton.title = @"Connect";
        self.connected = NO;
        self.fileList  = nil;
        [self.fileTable reloadData];
        self.outputLinesBuffer = nil;
    }
    
    if ([line rangeOfString:@"Connected."].location != NSNotFound) {
        self.startStopButton.title = @"Disconnect";
        self.connected = YES;
    }
    
    if (self.state == kNextStepDir && [line hasPrefix:@"Remote file list:"]) {
        
        //we are going to receive the list of file at next call
        self.state = kNextStepRemoteFileList;
        NSLog(@"+++ Remote File List +++");
        
    } else if (self.state == kNextStepRemoteFileList) {
        
        //receiving list of available available files, store them as table data source
        NSLog(@"+++ File List +++");
        if (!self.outputLinesBuffer) self.outputLinesBuffer = [[NSMutableArray alloc] init];
        [self.outputLinesBuffer addObject:line];
        
        if ([line hasSuffix:@"tsunami> "]) {
            
            //we have received the complete file list - no more next step
            NSLog(@"+++ File list is complete");
            //[self performSelectorInBackground:@selector(parseFileList) withObject:self];
            self.fileList = [self parseFileList];
            NSLog(@"fileTable : %@", self.fileTable);
            [self.fileTable reloadData];
        }
        
    }
    
    if ([line hasSuffix:@"tsunami> "]) {
        NSLog(@"STATE is now ready to accept other commands");
        self.state = kNextStepReady;
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationClientReady object:self];
    }
    
    
}

// add output to TextOutput & scroll to the last line
- (void) addTextToOuput:(NSString*)text {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", text]];
        
        [self.outputText.textStorage appendAttributedString:attr];
        [self.outputText scrollRangeToVisible:NSMakeRange([[self.outputText string] length], 0)];
    });
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
    self.statusButton.image    = [NSImage imageNamed:@"NSStatusNone"];
    
    self.connected = NO;
    self.fileList = nil;
    [self.fileTable reloadData];
    
    
    if (self.task)
        [self.task terminate];
    self.task   = nil;
    self.outputLinesBuffer = nil;
    [self addTextToOuput:@"\n+++ terminated +++\n"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

#pragma mark Settings Window

// catch programmatic close or user clicking on close button
-(void)settingsWindowWillClose:(NSNotification *)notification {

    NSLog(@"settingsWindowWillClose for window %@", notification.object);
    if (self.settingsWindow && notification.object == self.settingsWindow.window) {
        self.settingsWindow = nil;
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self.settingsWindow.window];
        
        //when download directory changes - we need to restart the client from the new directory
        if (self.task && self.task.isRunning) {
            
            NSString* newDirectory = [[NSUserDefaults standardUserDefaults] objectForKey:@"client_dir"];
            if ( ! [self.task.currentDirectoryPath isEqualToString:newDirectory]) {
                
                NSLog(@"New Directory !");
                [self sendCommand:@"quit"];
                
                //give the time the client to terminate, then restart
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self handleConnectButton:self];
                });
                
            }
        }
    }
}


- (IBAction)handleSettingsButton:(id)sender {
    
    //one time object creation
    if (!self.settingsWindow) {
        
        self.settingsWindow = [[NSWindowController alloc] initWithWindowNibName:@"SettingsPanel"];
        [self.settingsWindow showWindow:self];
        
        //register for "Window Will Close" notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsWindowWillClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:self.settingsWindow.window];

    } else {
        [self.settingsWindow.window performClose:self];
    }
    
}

// enable / disable the start/stop button depending on content of "Server Address" text field
- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self.startStopButton setEnabled:(self.serverAddress.stringValue.length > 0)];
}

//persist value to preferences
- (void)controlTextDidEndEditing:(NSNotification *)aNotificationNotification {
    NSLog(@"ClientViewController : controlTextDidEndEditing");
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:self.serverAddress.stringValue forKey:@"server_address"];
    [prefs synchronize];
}

#pragma mark Handle double click
- (void)doubleClick:(id)object {

    NSInteger row = [self.fileTable clickedRow];
    NSLog(@"User double clicked row %ld", row);
    
    //retrive the value from the Array -> NSData -> Custom struct
    NSData* data = [self.fileList objectAtIndex:row];
    file_item item;
    [data getBytes:&item length:sizeof(item)];
    
    [self sendCommand:[NSString stringWithFormat:@"get %@", item.name]];
}

#pragma mark Table Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {

    if (self.fileTable)
        return self.fileList.count;
    else
        return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    
    //retrive the value from the Array -> NSData -> Custom struct
    NSData* data = [self.fileList objectAtIndex:row];
    file_item item;
    [data getBytes:&item length:sizeof(item)];
    
    if ([column.identifier isEqualToString:@"filename"])
        return item.name;
    else
        return [NSString stringWithFormat:@"%ld", (unsigned long)item.size];
}

@end
