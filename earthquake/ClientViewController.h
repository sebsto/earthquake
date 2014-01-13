//
//  ClientViewController.h
//  earthquake
//
//  Created by Sébastien Stormacq on 03/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ClientViewController : NSViewController <NSTextFieldDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSTextField *serverAddress;
@property (weak) IBOutlet NSButton    *startStopButton;
@property (weak) IBOutlet NSButton    *statusButton;
@property (weak) IBOutlet NSButton    *settingsButton;
@property (weak) IBOutlet NSTableView *fileTable;

@property (unsafe_unretained) IBOutlet NSTextView *outputText;

@property NSTask *task;
@property NSFileHandle* input;

@property BOOL connected;

@property NSInteger         state;
@property NSMutableArray*   outputLinesBuffer;
@property NSMutableArray*   commandQueue;
@property NSArray*          fileList;

@property (strong) NSWindowController* settingsWindow;

@end


enum {
    kNextStepUnknow,
    kNextStepReady,
    kNextStepDir,
    kNextStepRemoteFileList,
    kNextStepWait
    
};

NSString * const kNotificationClientReady = @"kNotificationTsunamiClientReady";

typedef struct file_item {
    __unsafe_unretained NSString   *name;
                        NSUInteger size;
} file_item;

