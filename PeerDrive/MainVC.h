//
//  MainVC.h
//  PeerDriveTest
//
//  Created by Rayser on 30/4/14.
//  Copyright (c) 2014 HereNow. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import "MPManager.h"
#import "AFNetworking.h"
#import <MapKit/MapKit.h>
#import <RMCore/RMCore.h>

@interface MainVC : UIViewController <CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, RMCoreDelegate>
{
    NSString *myName;
    double mySpeed;
    double myDirection;
    double myLatitude;
    double myLongitude;
    
    CMMotionActivity *myActivity;
    
    int peerCount;
    
    BOOL firstLocationUpdate;
    
    BOOL iAmRomo;
}

@property (nonatomic, weak) IBOutlet UILabel *lblWarning;
@property (nonatomic, weak) IBOutlet UILabel *lblMovementMode;
@property (nonatomic, weak) IBOutlet UILabel *lblYourSpeed;
@property (nonatomic, weak) IBOutlet UILabel *lblYourDirection;
@property (nonatomic, weak) IBOutlet UILabel *lblYourPosition;

@property (nonatomic, strong) NSOperationQueue *coreMotionQueue;

@property (nonatomic, strong) CMMotionActivityManager *motionActivityManager;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) MPManager *mpManager;
@property (nonatomic, strong) AFHTTPRequestOperationManager *opsMan;

@property (nonatomic, strong) NSMutableArray *arrayOfPeers; //peer infoDicts from MP
@property (nonatomic, strong) NSMutableArray *arrayOfPeerData; //peerDicts from Cloud

@property (nonatomic, strong) UITableView *peersTableView;

@property (nonatomic, weak) IBOutlet MKMapView *mapView;

@property (nonatomic, weak) IBOutlet UIButton *mapToggleButton;

@property (nonatomic, strong) RMCoreRobotRomo3 *Romo3;

@end
