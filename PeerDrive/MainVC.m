//
//  MainVC.m
//  PeerDriveTest
//
//  Created by Rayser on 30/4/14.
//  Copyright (c) 2014 HereNow. All rights reserved.
//

#import "MainVC.h"
#import <math.h>
#import <AudioToolbox/AudioServices.h>

#define TIME_INTERVAL           6.0
#define WARNING_FLASH_DURATION  2.0
#define TABLE_ORIGIN_Y          220.0

static NSString * const CELL_REUSE_IDENTIFIER = @"peer_cell";

@interface MainVC ()

@end

@implementation MainVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        
        firstLocationUpdate = YES;
        iAmRomo = NO;
        
        peerCount = 0;
        
        self.arrayOfPeers = [[NSMutableArray alloc] initWithCapacity:0]; //from MP
        self.arrayOfPeerData = [[NSMutableArray alloc] initWithCapacity:0]; //from Cloud
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self setupUI];
    [self setupMotionManager];
    [self setupLocationManager];
    [self setupMpManager];
    [self setupDaCloud];
    [self setupTableView];
    [self setupMapView];
    
    [RMCore setDelegate:self];
    
    myName = [UIDevice currentDevice].name;
    
    [self performSelector:@selector(keepCallingMe) withObject:nil afterDelay:2.0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupUI {
    
    [self.lblWarning setHidden:YES];
}

#pragma mark - Warning UI

- (void)triggerWarning:(NSString *)peerName {
    
    self.view.backgroundColor = [UIColor redColor];
    [self.lblWarning setText:[NSString stringWithFormat:@"WARNING - %@", peerName]];
    [self.lblWarning setHidden:NO];
    
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    [self.Romo3 stopDriving];
}

- (void)returnToNormal {
    
    self.view.backgroundColor = [UIColor colorWithRed:60.0/255.0 green:180.0/255.0 blue:255.0/255.0 alpha:1.0];
    [self.lblWarning setHidden:YES];
    [self.lblWarning setText:@"WARNING"];
}

#pragma mark - Core Motion

- (void)setupMotionManager {
    
    self.coreMotionQueue = [[NSOperationQueue alloc] init];
    
    if ([CMMotionActivityManager isActivityAvailable]) {
        
        NSLog(@"CoreMotionActivity available");
        
        self.motionActivityManager = [[CMMotionActivityManager alloc] init];
        
        [self.motionActivityManager startActivityUpdatesToQueue:self.coreMotionQueue withHandler:^(CMMotionActivity *activity) {
            
            //            [self.automotiveBGView setHidden:YES];
            
            NSString *display;
            
            myActivity = activity;
            
            if (activity.automotive) {
                display = @"You Are Driving";
                //                [self.automotiveBGView setHidden:NO];
            }
            else if (activity.stationary) {
                display = @"You Are Still";
            }
            else if (activity.walking) {
                display = @"You Are Walking";
            }
            else if (activity.running) {
                display = @"You Are Running";
            }
            else {
                display = @"Can't Tell Your Movement";
            }
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self.lblMovementMode setText:display];
            }];
        }];
    }
    else {
        
        NSLog(@"CoreMotionActivity NOT available");
    }
}

#pragma mark - Core Location

- (void)setupLocationManager {
    
    self.locationManager = [[CLLocationManager alloc] init];
    [self.locationManager setDelegate:self];
    
    [self.locationManager setDistanceFilter:kCLDistanceFilterNone];
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
    
    [self.locationManager startUpdatingHeading];
    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    
    CLLocation *loc = locations.lastObject;
    
    mySpeed = loc.speed;
    myDirection = loc.course;
    myLatitude = loc.coordinate.latitude;
    myLongitude = loc.coordinate.longitude;
    
    [self.lblYourSpeed setText:[NSString stringWithFormat:@"Your Speed: %f", mySpeed]];
    [self.lblYourDirection setText:[NSString stringWithFormat:@"Your Direction: %f", myDirection]];
    [self.lblYourPosition setText:[NSString stringWithFormat:@"Your Position: %f, %f", myLatitude, myLongitude]];
    
    if (firstLocationUpdate) {
        
        [self addAnnotationToMap:loc.coordinate andTitle:@"Me"];
        [self updateDirectionOfArrowAnnotationFor:@"Me" withDirection:myDirection];
        
        MKCoordinateRegion region;
        MKCoordinateSpan span;
        span.latitudeDelta = 0.0000005;
        span.longitudeDelta = 0.000005;
        region.span = span;
        region.center = loc.coordinate;
        
        [self.mapView setRegion:region animated:NO];
        
        firstLocationUpdate = NO;
    }
    else {
        
        [self updateAnnotation:@"Me" withCoordinates:loc.coordinate];
        [self updateDirectionOfArrowAnnotationFor:@"Me" withDirection:myDirection];
        
        MKCoordinateRegion region;
        MKCoordinateSpan span = self.mapView.region.span;
        region.span = span;
        region.center = loc.coordinate;
        
        [self.mapView setRegion:region animated:NO];
    }
    
    //send data to multipeer here
    [self sendInfoToPeers];
}

#pragma mark - Multipeer

- (void)setupMpManager {
    
    self.mpManager = [[MPManager alloc] init];
    
    [self.mpManager setupPeerAndSessionWithDisplayName:[UIDevice currentDevice].name serviceType:@"peer-drive"];
    
    NSMutableDictionary *discoveryDict = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    //used to compare to decide who is the host
    [discoveryDict setObject:[self stringFromDate:[NSDate date]] forKey:@"timestamp"];
    
    [self.mpManager advertiseSelf:YES withDiscoveryInfo:discoveryDict];
    [self.mpManager browsePeers];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(foundPeerWithDiscoveryInfo:)
                                                 name:@"MPManager::foundPeerWithDiscoveryInfo"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lostPeer:)
                                                 name:@"MPManager::lostPeer"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveDataDict:)
                                                 name:@"MPManager::didReceiveData"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeStateNotificationFromMPManager:)
                                                 name:@"MPManager::didChangeState"
                                               object:nil];
}

- (void)foundPeerWithDiscoveryInfo:(NSNotification *)notification {
    
    NSLog(@"found peer");
    
    //add to array of detected peers, checking for duplicates
    
    NSDictionary *peerInfo = notification.userInfo;
    
    int count = 0;
    
    for (NSDictionary *peerDict in self.arrayOfPeers) {
        
        MCPeerID *peerID = [peerInfo objectForKey:@"peerID"];
        MCPeerID *peerName = [peerDict objectForKey:@"peerID"];
        
        if ([peerName.displayName isEqualToString:peerID.displayName]) {
            
            count++;
        }
    }
    
    if (count == 0) {
        
        [self.arrayOfPeers addObject:peerInfo];
    }
    
    [self invitationsHandler];
}

- (void)lostPeer:(NSNotification *)notification {
    
    MCPeerID *peerID = [notification.userInfo objectForKey:@"peerID"];
    //remove from array
    
    NSUInteger indexToRemove = -1;
    
    for (NSDictionary *peerDict in self.arrayOfPeers) {
        
        MCPeerID *aPeerID = [peerDict objectForKey:@"peerID"];
        NSString *peerName = aPeerID.displayName;
        
        if ([peerName isEqualToString:peerID.displayName]) {
            
            indexToRemove = [self.arrayOfPeers indexOfObject:peerDict];
        }
    }
    
    [self.arrayOfPeers removeObjectAtIndex:indexToRemove];
}

- (void)invitationsHandler {
    
    NSLog(@"invitations handler");
    
    NSDictionary *myDict = [[self.mpManager advertiser] discoveryInfo];
    
    NSDate *myDate = [self dateFromString:[myDict objectForKey:@"timestamp"]];
    
    NSDate *iAmHost;
    
    for (NSDictionary *peerDict in self.arrayOfPeers) {
        
        NSDictionary *discoveryInfo = [peerDict objectForKey:@"discoveryInfo"];
        
        NSDate *peerDate = [self dateFromString:[discoveryInfo objectForKey:@"timestamp"]];
        
        if ([myDate compare:peerDate] == NSOrderedDescending) {
            
            iAmHost = myDate;
        }
        else {
            
            iAmHost = peerDate;
        }
    }
    
    if ([iAmHost compare:myDate] == NSOrderedSame) {
        
        //i am host, so invite everyone
        
        for (NSDictionary *peerDict in self.arrayOfPeers) {
        
            MCPeerID *peerID = [peerDict objectForKey:@"peerID"];
            
            if (![[[self.mpManager session] connectedPeers] containsObject:peerID]) {
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [[self.mpManager browser] invitePeer:peerID toSession:[self.mpManager session] withContext:nil timeout:5.0];
                }];
            }
        }
    }
}

- (void)didReceiveDataDict:(NSNotification *)notification {
    
    NSLog(@"Received Data Dict");
    
    NSDictionary *recordDict = [notification.userInfo objectForKey:@"receivedDict"];
    
    //same code to handle new peerDicts
    
    NSString *username = [recordDict objectForKey:@"username"];
    double direction = [[recordDict objectForKey:@"direction"] doubleValue];
    double speed = [[recordDict objectForKey:@"speed"] doubleValue];
    double latitude = [[recordDict objectForKey:@"latitude"] doubleValue];
    double longitude = [[recordDict objectForKey:@"longitude"] doubleValue];
    
    BOOL isRomo = NO;
    if ([recordDict objectForKey:@"romo"]) {
         isRomo = [[recordDict objectForKey:@"romo"] boolValue];
    }

    NSString *activity = [recordDict objectForKey:@"activity"];
    
    NSDate *recDate = [self dateFromString:[recordDict objectForKey:@"created_at"]];
    
    if ([username isEqualToString:myName]) {
        
        //ignore this data, since it's myself
    }
    else if (!username) {
        
    }
    else {
        
        NSUInteger index = [self usernameExistsInPeerDataArray:username];
        
        NSMutableDictionary *peerDict = [[NSMutableDictionary alloc] initWithCapacity:0];
        [peerDict setObject:username forKey:@"name"];
        [peerDict setObject:[NSNumber numberWithDouble:speed] forKey:@"speed"];
        [peerDict setObject:[NSNumber numberWithDouble:direction] forKey:@"direction"];
        [peerDict setObject:[NSNumber numberWithDouble:latitude] forKey:@"latitude"];
        [peerDict setObject:[NSNumber numberWithDouble:longitude] forKey:@"longitude"];
        [peerDict setObject:recDate forKey:@"created_at"];
        [peerDict setObject:activity forKey:@"activity"];
        [peerDict setObject:[NSNumber numberWithBool:isRomo] forKey:@"romo"];
        
        if (index == -1) {
            
            //does not exist, add to array
            
            [self.arrayOfPeerData addObject:peerDict];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                
                [self addAnnotationToMap:CLLocationCoordinate2DMake(latitude, longitude) andTitle:username];
                [self updateDirectionOfArrowAnnotationFor:username withDirection:direction];
            }];
        }
        else {
            
            //exists, update relevant entry in arrayOfPeerData
            
            NSDictionary *aRec = [self.arrayOfPeerData objectAtIndex:index];
            
            NSDate *aRecDate = [aRec objectForKey:@"created_at"];
            
            if ([recDate compare:aRecDate] == NSOrderedDescending) {
                
                //record from multipeer is higher
                
                [self.arrayOfPeerData replaceObjectAtIndex:index withObject:peerDict];
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    
                    [self updateAnnotation:username withCoordinates:CLLocationCoordinate2DMake(latitude, longitude)];
                    [self updateDirectionOfArrowAnnotationFor:username withDirection:direction];
                }];
                
                NSLog(@"Updated Peer Array Data from Multipeer");
            }
            else {
                
                //do nothing
            }
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            [self.peersTableView reloadData];
            [self projectPaths:peerDict];
        }];
    }
}

- (void)didChangeStateNotificationFromMPManager:(NSNotification*)notification {
    
    int state = [[notification.userInfo objectForKey:@"state"] intValue];
    MCPeerID *peerID = [notification.userInfo objectForKey:@"peerID"];
    
    switch (state) {
		case MCSessionStateConnected:
            NSLog(@"PEER CONNECTED: %@", peerID.displayName);
			break;
		case MCSessionStateConnecting:
            NSLog(@"PEER CONNECTING: %@", peerID.displayName);
			break;
		case MCSessionStateNotConnected: {
            NSLog(@"PEER NOT CONNECTED: %@", peerID.displayName);
			break;
        }
	}
}

- (BOOL)checkIfPeerInRangeOfMultiPeerDetection:(NSString *)peerName {
    
    //check if peer is within range of multipeer detection
    
    BOOL isInRange = NO;
    
    for (NSString *aName in self.arrayOfPeers) {
        
        if ([aName isEqualToString:peerName]) {
            
            isInRange = YES;
        }
    }
    
    return isInRange;
}

- (void)sendInfoToPeers {
    
    NSMutableDictionary *myDict = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    [myDict setObject:[UIDevice currentDevice].name forKey:@"username"];
    [myDict setObject:[NSNumber numberWithDouble:mySpeed] forKey:@"speed"];
    [myDict setObject:[NSNumber numberWithDouble:myDirection] forKey:@"direction"];
    [myDict setObject:[NSNumber numberWithDouble:myLatitude] forKey:@"latitude"];
    [myDict setObject:[NSNumber numberWithDouble:myLongitude] forKey:@"longitude"];
    [myDict setObject:[self currentActivityString] forKey:@"activity"];
    [myDict setObject:[self stringFromDate:[NSDate date]] forKey:@"created_at"];
    
    if (iAmRomo) {
        [myDict setObject:[NSNumber numberWithBool:YES] forKey:@"romo"];
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:myDict];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
       
        [[self.mpManager session] sendData:data toPeers:[self.mpManager session].connectedPeers withMode:MCSessionSendDataReliable error:nil];
    }];
}

#pragma mark - Prediction Engine

- (void)projectPaths:(NSDictionary *)peerDict {
    
    double timeInterval = TIME_INTERVAL;
    double distanceWarningFilter = 20.0; //number large to account for inaccuracy of GPS data
    
    CLLocationCoordinate2D myPredictedCoordinates = [self newCoordinatesAfterTime:timeInterval withSpeed:mySpeed andDirection:myDirection fromCurrentPosition:CLLocationCoordinate2DMake(myLatitude, myLongitude)];
    
    CLLocationCoordinate2D peerPredictedCoordinates;
    
    NSString *peerName = [peerDict objectForKey:@"name"];
    double peerDirection = [[peerDict objectForKey:@"direction"] doubleValue];
    double peerSpeed = [[peerDict objectForKey:@"speed"] doubleValue];
    double peerLatitude = [[peerDict objectForKey:@"latitude"] doubleValue];
    double peerLongitude = [[peerDict objectForKey:@"longitude"] doubleValue];
    
    NSString *peerActivity;
    if ([peerDict objectForKey:@"activity"] && [peerDict objectForKey:@"activity"] != [NSNull null])
        peerActivity = [peerDict objectForKey:@"activity"];
    
    peerPredictedCoordinates = [self newCoordinatesAfterTime:timeInterval withSpeed:peerSpeed andDirection:peerDirection fromCurrentPosition:CLLocationCoordinate2DMake(peerLatitude, peerLongitude)];
    
    CLLocation *my;
    
    if ([CMMotionActivityManager isActivityAvailable]) {
        
        if (myActivity.automotive || myActivity.walking || myActivity.running) {
            
            //if in motion, use predicted values
            
            my = [[CLLocation alloc] initWithLatitude:myPredictedCoordinates.latitude longitude:myPredictedCoordinates.longitude];
        }
        else {
            
            //if stationary or can't tell movement type, use current latitude longitude
            
            my = [[CLLocation alloc] initWithLatitude:myLatitude longitude:myLongitude];
        }
    }
    else {
        
        //if no CoreMotion, defaults to predicted latitude longitude
        
        my = [[CLLocation alloc] initWithLatitude:myPredictedCoordinates.latitude longitude:myPredictedCoordinates.longitude];
    }
    
    CLLocation *his = [[CLLocation alloc] initWithLatitude:peerPredictedCoordinates.latitude longitude:peerPredictedCoordinates.longitude];
    
    //predicted distance apart after timeInterval
    CLLocationDistance dist = [my distanceFromLocation:his];
    
    //flash warning if projected distance between 2 devices is less than distanceWarningFilter. *FOR TESTING PURPOSES ONLY*
    if (dist < distanceWarningFilter) {
        
        //check if speed is too fast, cannot stop within distanceWarningFilter or so
        //currently not checking since we are testing on foot, speed data is vastly inaccurate.
        
        //if (mySpeed > 30 || hisSpeed > 30) {
        //}
        
        double differential = fabs(myDirection - peerDirection);
        
        if (differential < 30.0 || differential > 330.0) {
            
            //if differential is 20 degrees, estimated to be parallel direction, no collision warning
            //(340 to take into account zero-point, 20 degrees differential from 0.0)
        }
        else if (165.0 < differential && differential < 195.0) {
            
            //else if differential is 170-190 degrees, estimated to be opposite directions, opposite sides of road, no collision warning
        }
        else {
            
            //check if peers are both still
            
            if ([peerActivity isEqualToString:@"still"] && [[self currentActivityString] isEqualToString:@"still"]) {
                
                //don't need to warn
            }
            else {
                
                //collision warning
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    
                    [self triggerWarning:peerName];
                    [self performSelector:@selector(returnToNormal) withObject:nil afterDelay:WARNING_FLASH_DURATION];
                }];
            }
        }
    }
}

#pragma mark - Distance Prediction

- (CLLocationCoordinate2D)newCoordinatesAfterTime:(double)time withSpeed:(double)speed andDirection:(double)direction fromCurrentPosition:(CLLocationCoordinate2D)coordinates {
    
    //latitude
    double latitude = coordinates.latitude;
    //longitude
    double longitude = coordinates.longitude;
    
    //predicted lat
    double myNewLat;
    //predicted lng
    double myNewLng;
    
    //pi
    //M_PI
    
    //earth radius (in meters)
    double earthRadius = 6378137.0;
    
    double x = speed * sin(direction*M_PI/180) * time / 3600;
    double y = speed * cos(direction*M_PI/180) * time / 3600;
    
    myNewLat = latitude + 180 / M_PI * y / earthRadius;
    myNewLng = longitude + 180 / M_PI / sin(latitude * M_PI/180) * x / earthRadius;
    
    return CLLocationCoordinate2DMake(myNewLat, myNewLng);
}

#pragma mark - Ridin' on da' Clouds

- (void)setupDaCloud {
    
    self.opsMan = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://raydius-staging.herokuapp.com/"]];
    AFJSONResponseSerializer *serializer = [[AFJSONResponseSerializer alloc] init];
    [self.opsMan setResponseSerializer:serializer];
}

- (void)keepCallingMe {

    //if you are NOT driving, don't connect to cloud
    if (!myActivity.automotive) {

        //You are NOT Driving!
        
        if (self.arrayOfPeerData.count > 0) {
            
            //stop connect since there is data
            return;
        }
        else {
            
            //but table empty
            //kinda like if multipeer didn't establish and array is empty
            //continue with cloud
        }
    }
    
    NSMutableDictionary *queryInfo = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    [queryInfo setObject:myName forKey:@"username"];
    [queryInfo setObject:[NSNumber numberWithDouble:mySpeed] forKey:@"speed"];
    [queryInfo setObject:[NSNumber numberWithDouble:myDirection] forKey:@"direction"];
    [queryInfo setObject:[NSNumber numberWithDouble:myLatitude] forKey:@"latitude"];
    [queryInfo setObject:[NSNumber numberWithDouble:myLongitude] forKey:@"longitude"];
    [queryInfo setObject:[self currentActivityString] forKey:@"activity"];
    
    [self.opsMan POST:@"api/posts/peerdrivetest" parameters:queryInfo success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSMutableArray *arrayOfRecords = [NSMutableArray arrayWithArray:responseObject];
        
        for (NSDictionary *recordDict in arrayOfRecords) {
            
            NSString *username = [recordDict objectForKey:@"username"];
            double direction = [[recordDict objectForKey:@"direction"] doubleValue];
            double speed = [[recordDict objectForKey:@"speed"] doubleValue];
            double latitude = [[recordDict objectForKey:@"latitude"] doubleValue];
            double longitude = [[recordDict objectForKey:@"longitude"] doubleValue];
            NSString *activity = [recordDict objectForKey:@"activity"];
            
            NSDate *recDate = [self dateFromString:[recordDict objectForKey:@"created_at"]];
            
            if ([username isEqualToString:myName]) {
                
                //ignore this data, since it's myself
            }
            else {
                
                NSUInteger index = [self usernameExistsInPeerDataArray:username];
                
                NSMutableDictionary *peerDict = [[NSMutableDictionary alloc] initWithCapacity:0];
                [peerDict setObject:username forKey:@"name"];
                [peerDict setObject:[NSNumber numberWithDouble:speed] forKey:@"speed"];
                [peerDict setObject:[NSNumber numberWithDouble:direction] forKey:@"direction"];
                [peerDict setObject:[NSNumber numberWithDouble:latitude] forKey:@"latitude"];
                [peerDict setObject:[NSNumber numberWithDouble:longitude] forKey:@"longitude"];
                [peerDict setObject:recDate forKey:@"created_at"];
                [peerDict setObject:activity forKey:@"activity"];
                
                if (index == -1) {
                    
                    //does not exist, add to array
                    
                    [self.arrayOfPeerData addObject:peerDict];
                    [self addAnnotationToMap:CLLocationCoordinate2DMake(latitude, longitude) andTitle:username];
                    [self updateDirectionOfArrowAnnotationFor:username withDirection:direction];
                }
                else {
                    
                    //exists, update relevant entry in arrayOfPeerData
                    
                    NSDictionary *aRec = [self.arrayOfPeerData objectAtIndex:index];
                    
                    NSDate *aRecDate = [aRec objectForKey:@"created_at"];
                    
                    if ([recDate compare:aRecDate] == NSOrderedDescending) {
                        
                        //record from cloud is higher
                        
                        [self.arrayOfPeerData replaceObjectAtIndex:index withObject:peerDict];
                        
                        [self updateAnnotation:username withCoordinates:CLLocationCoordinate2DMake(latitude, longitude)];
                        [self updateDirectionOfArrowAnnotationFor:username withDirection:direction];
                        
                        NSLog(@"Updated Peer Array Data from Cloud");
                    }
                    else {
                        
                        //do nothing
                    }
                }
                
                [self.peersTableView reloadData];
                [self projectPaths:peerDict];
            }
        }
        
        //call API again after timeInterval to retrieve next set of data
        [self performSelector:@selector(keepCallingMe) withObject:nil afterDelay:TIME_INTERVAL];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
    }];
}

#pragma mark - Table View

- (void)setupTableView {
    
    CGFloat frameHeight = self.view.bounds.size.height - TABLE_ORIGIN_Y;
    
    self.peersTableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, TABLE_ORIGIN_Y, 320.0, frameHeight) style:UITableViewStylePlain];
    [self.view addSubview:self.peersTableView];
    
    [self.peersTableView setDelegate:self];
    [self.peersTableView setDataSource:self];
    [self.peersTableView setBackgroundColor:[UIColor clearColor]];
    
    [self.view bringSubviewToFront:self.mapView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.arrayOfPeerData.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 66.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CELL_REUSE_IDENTIFIER];
    
    if (!cell) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CELL_REUSE_IDENTIFIER];
        [cell setBackgroundColor:[UIColor clearColor]];
        
        UILabel *lblPeerName = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 16.0)];
        [lblPeerName setTag:1];
        [lblPeerName setBackgroundColor:[UIColor clearColor]];
        [lblPeerName setTextColor:[UIColor whiteColor]];
        [lblPeerName setFont:[UIFont systemFontOfSize:13.0]];
        
        UILabel *lblPeerSpeed = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 16.5, 320.0, 16.0)];
        [lblPeerSpeed setTag:2];
        [lblPeerSpeed setBackgroundColor:[UIColor clearColor]];
        [lblPeerSpeed setTextColor:[UIColor whiteColor]];
        [lblPeerSpeed setFont:[UIFont systemFontOfSize:13.0]];
        
        UILabel *lblPeerDirection = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 33.0, 320.0, 16.0)];
        [lblPeerDirection setTag:3];
        [lblPeerDirection setBackgroundColor:[UIColor clearColor]];
        [lblPeerDirection setTextColor:[UIColor whiteColor]];
        [lblPeerDirection setFont:[UIFont systemFontOfSize:13.0]];
        
        UILabel *lblPeerPosition = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 49.5, 320.0, 16.0)];
        [lblPeerPosition setTag:4];
        [lblPeerPosition setBackgroundColor:[UIColor clearColor]];
        [lblPeerPosition setTextColor:[UIColor whiteColor]];
        [lblPeerPosition setFont:[UIFont systemFontOfSize:13.0]];
        
        [cell addSubview:lblPeerName];
        [cell addSubview:lblPeerSpeed];
        [cell addSubview:lblPeerDirection];
        [cell addSubview:lblPeerPosition];
    }
    
    NSDictionary *peerDict = [self.arrayOfPeerData objectAtIndex:indexPath.row];
    
    UILabel *lblPeerName = (UILabel *)[cell viewWithTag:1];
    UILabel *lblPeerSpeed = (UILabel *)[cell viewWithTag:2];
    UILabel *lblPeerDirection = (UILabel *)[cell viewWithTag:3];
    UILabel *lblPeerPosition = (UILabel *)[cell viewWithTag:4];
    
    [lblPeerName setText:[NSString stringWithFormat:@"Peer: %@", [peerDict objectForKey:@"name"]]];
    [lblPeerSpeed setText:[NSString stringWithFormat:@"Peer Speed: %f", [[peerDict objectForKey:@"speed"] doubleValue]]];
    [lblPeerDirection setText:[NSString stringWithFormat:@"Peer Direction: %f", [[peerDict objectForKey:@"direction"] doubleValue]]];
    [lblPeerPosition setText:[NSString stringWithFormat:@"Peer Position: %f, %f", [[peerDict objectForKey:@"latitude"] doubleValue], [[peerDict objectForKey:@"longitude"] doubleValue]]];
    
    return cell;
}

- (NSUInteger)usernameExistsInPeerDataArray:(NSString *)peerName {
    
    NSUInteger exists = -1;
    
    for (NSDictionary *peerDict in self.arrayOfPeerData) {
        
        if ([peerName isEqualToString:[peerDict objectForKey:@"name"]]) {
            
            exists = [self.arrayOfPeerData indexOfObject:peerDict];
        }
    }
    
    return exists;
}

#pragma mark - Map View

- (void)setupMapView {
    
    [self.mapView setHidden:YES];
}

- (IBAction)showOrHideMapView {
    
    if (self.mapView.hidden) {
        
        [self.mapView setHidden:NO];
        [self.Romo3 driveForwardWithSpeed:1.0];
    }
    else {
        
        [self.mapView setHidden:YES];
        [self.Romo3 stopDriving];
    }
}

- (void)addAnnotationToMap:(CLLocationCoordinate2D)coordinates andTitle:(NSString *)peerName {
    
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    
    [annotation setCoordinate:coordinates];
    [annotation setTitle:peerName];
    
    [self.mapView addAnnotation:annotation];
}

- (void)updateAnnotation:(NSString *)peerName withCoordinates:(CLLocationCoordinate2D)coordinates {
    
    for (MKPointAnnotation *aPin in self.mapView.annotations) {
        
        if ([aPin.title isEqualToString:peerName]) {
            [aPin setCoordinate:coordinates];
        }
    }
}

- (void)updateDirectionOfArrowAnnotationFor:(NSString *)peerName withDirection:(double)direction {
    
    for (MKPointAnnotation *aPin in self.mapView.annotations) {
        
        if ([aPin.title isEqualToString:peerName]) {
            
            MKAnnotationView *view = (MKAnnotationView *)[self.mapView viewForAnnotation:aPin];
            UIImageView *imgView = (UIImageView *)[view viewWithTag:999];
            
            if (imgView) {
                
                imgView.transform = CGAffineTransformMakeRotation(direction * M_PI/180);
            }
            else {
            }
        }
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    
    static NSString *annotationReuseID = @"Annotation_View";
    
    MKPinAnnotationView *aPinView = (MKPinAnnotationView *)[self.mapView dequeueReusableAnnotationViewWithIdentifier:annotationReuseID];
    
    if (!aPinView) {
        
        MKAnnotationView *annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationReuseID];
        
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(-10, -10, 20, 20)];
        [imgView setContentMode:UIViewContentModeScaleAspectFit];
        
        MKPointAnnotation *meAnnotation = (MKPointAnnotation *)annotation;
        if ([meAnnotation.title isEqualToString:@"Me"]) {
            [imgView setImage:[UIImage imageNamed:@"Blue_Arrow"]];
        }
        else {
            [imgView setImage:[UIImage imageNamed:@"Red_Arrow"]];
        }
        
        [imgView setTag:999];
        [annotationView addSubview:imgView];
        
        return annotationView;
    }
    else {
        
        aPinView.annotation = annotation;
        
        return aPinView;
    }
}

#pragma mark - Utility Methods

- (NSString *)stringFromDate:(NSDate *)date {
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    
    return [formatter stringFromDate:date];
}

- (NSDate *)dateFromString:(NSString *)dateString {
    
    if (!dateString) return nil;
    if ([dateString hasSuffix:@"Z"]) {
        dateString = [[dateString substringToIndex:(dateString.length-1)] stringByAppendingString:@"-0000"];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    
    return [formatter dateFromString:dateString];
}

- (NSString *)currentActivityString {
    
    NSString *string;
    
    if (myActivity.automotive) {
        string = @"driving";
    }
    else if (myActivity.walking) {
        string = @"walking";
    }
    else if (myActivity.running) {
        string = @"running";
    }
    else if (myActivity.stationary) {
        string = @"still";
    }
    else {
        string = @"unknown";
    }
    
    return string;
}

#pragma mark - Romo3 Methods

- (void)robotDidConnect:(RMCoreRobot *)robot {
    
    // Currently the only kind of robot is Romo3, so this is just future-proofing
    if ([robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        
        self.Romo3 = (RMCoreRobotRomo3 *)robot;
        
        // Change Romo's LED to be solid at 100% power
        [self.Romo3.LEDs setSolidWithBrightness:1.0];
        
        iAmRomo = YES;
        
        //play a sound, SY's voice
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot {
    
    iAmRomo = NO;
}

@end
