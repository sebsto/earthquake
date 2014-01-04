//
//  ClientViewController.h
//  earthquake
//
//  Created by Sébastien Stormacq on 03/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ClientViewController : NSViewController <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *serverAddress;
@property (weak) IBOutlet NSButton    *startStopButton;
@property (weak) IBOutlet NSButton    *statusButton;
@property (weak) IBOutlet NSButton    *settingsButton;
@property (weak) IBOutlet NSTableView *fileTable;

@property (unsafe_unretained) IBOutlet NSTextView *outputText;

@property NSTask *task;

@end
