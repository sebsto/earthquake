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
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs synchronize];

    
    NSString* client_dir = [prefs stringForKey:@"client_dir"];
    if (!client_dir)
        client_dir = [NSString stringWithFormat:@"%@/Downloads", NSHomeDirectory()];
    
    self.downloadFolder.stringValue = client_dir;
    
    NSString* server_port = [prefs stringForKey:@"server_port"];
    if (!server_port)
        server_port = @"46224";
    self.serverPortNumber.stringValue = server_port;
    
    NSString* block_size = [prefs stringForKey:@"block_size"];
    if (!block_size)
        block_size = @"8192";
    self.UDPBlockSize.stringValue     = block_size;
    
    self.view.window.delegate = (id<NSWindowDelegate>)self;
}

- (void)windowWillClose:(NSNotification *)notification {

    NSLog(@"SeetingsWindow windowWillClose");
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:self.downloadFolder.stringValue forKey:@"client_dir"];
    [prefs setObject:self.serverPortNumber.stringValue forKey:@"server_port"];
    [prefs setObject:self.UDPBlockSize.stringValue forKey:@"block_size"];
    [prefs synchronize];
    
}

- (IBAction)changeFolderButton:(id)sender {
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    // Enable the selection of directories in the dialog.
    [openDlg setCanChooseDirectories:YES];
    [openDlg setCanChooseFiles:NO];
    [openDlg setAllowsMultipleSelection:NO];
    
    // Display the dialog box.  If the OK pressed, process the files.
    [openDlg beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (NSFileHandlingPanelOKButton == result) {
        
            NSAssert([[openDlg URLs ]count] == 1, @"User can only select one file");
            NSURL* file = [[openDlg URLs] objectAtIndex:0];
            NSLog(@"Selected : %@", file);
            self.downloadFolder.stringValue = [file path];
        }
    }];
}

- (IBAction)closeButtonPressed:(id)sender {
    [self.view.window close];
}
@end
