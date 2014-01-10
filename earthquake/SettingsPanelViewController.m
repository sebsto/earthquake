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
    //[openDlg beginWithCompletionHandler:^(NSInteger result){
    [openDlg beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (NSFileHandlingPanelOKButton == result) {
        
            NSAssert([[openDlg URLs ]count] == 1, @"User can only select one file");
            NSURL* file = [[openDlg URLs] objectAtIndex:0];
            NSLog(@"Selected : %@", file);
            self.downloadFolder.stringValue = [file path];
        }
    }];
}

@end
