//
//  SettingsPanelViewController.m
//  earthquake
//
//  Created by Sébastien Stormacq on 05/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "SettingsPanelViewController.h"

@implementation SettingsPanelViewController

-(void)awakeFromNib {
    
    //set default values
    self.downloadFolder.stringValue = [NSString stringWithFormat:@"%@/Downloads", NSHomeDirectory()];
    self.serverPortNumber.stringValue = @"46224";
    self.UDPBlockSize.stringValue     = @"8192";
}

- (IBAction)changeFolderButton:(id)sender {
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
            self.downloadFolder.stringValue = [files objectAtIndex:0];
        }
    }
}

@end
