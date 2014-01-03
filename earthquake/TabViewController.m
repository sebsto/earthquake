//
//  TabViewController.m
//  earthquake
//
//  Created by Sébastien Stormacq on 03/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "TabViewController.h"

@implementation TabViewController 

-(void)awakeFromNib {
    
    NSTabView* tabView = (NSTabView*)self.view;

    //restore last tab position
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    id lastActiveTab = [defaults objectForKey:@"ActiveTab"];
    if (lastActiveTab) {
        [tabView selectTabViewItemWithIdentifier:lastActiveTab];
    } else {
        [tabView selectTabViewItemAtIndex:1];
    }
    
    //register itself as delegate to track future changes
    tabView.delegate = self;
    
    
}

-(void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    
    //save active tab to user defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:tabViewItem.identifier forKey:@"ActiveTab"];
}

@end
