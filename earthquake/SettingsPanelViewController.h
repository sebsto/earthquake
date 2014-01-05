//
//  SettingsPanelViewController.h
//  earthquake
//
//  Created by Sébastien Stormacq on 05/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SettingsPanelViewController : NSViewController

@property (weak) IBOutlet NSTextField *downloadFolder;
@property (weak) IBOutlet NSTextField *serverPortNumber;
@property (weak) IBOutlet NSTextField *UDPBlockSize;

@end
