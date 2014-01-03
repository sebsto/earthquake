//
//  Server.h
//  earthquake
//
//  Created by Sébastien Stormacq on 02/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ServerViewController : NSViewController <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *selectedDir;
@property (unsafe_unretained) IBOutlet NSTextView *outputText;
@property (weak) IBOutlet NSButton *startStopButton;

@property NSTask *task;

@end
