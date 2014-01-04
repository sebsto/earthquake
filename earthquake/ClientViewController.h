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
@property NSFileHandle* input;

//this class must implement kind of State Machine to keep track of outputs
#define NEXT_STEP_NONE              0x00
#define NEXT_STEP_DIR               0x02
#define NEXT_STEP_REMOTE_FILE_LIST  0x04

@property NSUInteger        state;
@property NSMutableArray*   buffer;

@end

typedef struct file_item {
    __unsafe_unretained NSString   *name;
                        NSUInteger size;
} file_item;

