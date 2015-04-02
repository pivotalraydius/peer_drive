//
//  AppDelegate.h
//  PeerDrive
//
//  Created by Rayser on 5/5/14.
//  Copyright (c) 2014 Herenow. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MainVC.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) MainVC *mainVC;

@property (strong, nonatomic) UINavigationController *navigationController;


@end
