//
//  MPManager.m
//  MPTest
//
//  Created by Rayser on 24/4/14.
//  Copyright (c) 2014 Herenow. All rights reserved.
//

#import "MPManager.h"

@implementation MPManager

-(id)init{
    
    self = [super init];
    
    if (self) {
        _peerID = nil;
        _session = nil;
        _browser = nil;
        _advertiser = nil;
    }
    
    return self;
}

-(void)setupPeerAndSessionWithDisplayName:(NSString *)displayName serviceType:(NSString*)serviceType{
    
    _peerID = [[MCPeerID alloc] initWithDisplayName:displayName];
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
    _serviceType = serviceType;
}

-(void)advertiseSelf:(BOOL)shouldAdvertise withDiscoveryInfo:(NSDictionary*)discoveryInfo {
    
    NSDictionary *discoveryInformation = discoveryInfo;
    if (!discoveryInformation) {
        discoveryInformation = [NSDictionary dictionary];
    }
    if (shouldAdvertise) {
        
//        _advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:_serviceType discoveryInfo:discoveryInformation session:_session];
//        [_advertiserAssistant setDelegate:self];
//        [_advertiserAssistant start];
        
        _advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_peerID discoveryInfo:discoveryInformation serviceType:_serviceType];
        [_advertiser setDelegate:self];
        [_advertiser startAdvertisingPeer];
        
        NSLog(@"Start advertising");
    }
    else {
        
//        [_advertiser stopAdvertisingPeer];
//        [_advertiserAssistant stop];
//        _advertiserAssistant = nil;
    }
}

-(void)browsePeers {
    
    if (!_browser) {
        _browser = [[MCNearbyServiceBrowser alloc] initWithPeer:_peerID serviceType:_serviceType];
        [_browser setDelegate:self];
    }
    
    [_browser startBrowsingForPeers];
}

-(void)stopAdvertising {

    if (_advertiser) {
        [_advertiser stopAdvertisingPeer];
    }
    else if (_advertiserAssistant) {
        [_advertiserAssistant stop];
    }
}

-(void)stopBrowsing {

    [_browser stopBrowsingForPeers];
}

#pragma mark - MCNearbyServiceAdvertiser delegates 

- (void) advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler {
    
    if (invitationHandler) {
        invitationHandler(YES, _session);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MPManager::didReceiveInvitationFromPeer"
                                                        object:nil
                                                      userInfo:nil];
}

#pragma mark - MCNearbyServiceBrowser delegates

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {

    NSLog(@"MPManager:: foundPeer with peerID: %@", [peerID displayName]);
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:0];
    [userInfo setObject:peerID forKey:@"peerID"];
    if (info) {
        [userInfo setObject:info forKey:@"discoveryInfo"];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MPManager::foundPeerWithDiscoveryInfo" object:nil userInfo:userInfo];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    
    NSLog(@"MPManager:: LostPeer with peerID: %@", [peerID displayName]);
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:0];
    [userInfo setObject:peerID forKey:@"peerID"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MPManager::lostPeer" object:nil userInfo:userInfo];
}

-(void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    
    NSLog(@"MPManager:: didNotStartBrowsingForPeers");
    
//    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:0];
//    [userInfo setObject:error forKey:@"error"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MPManager::didNotStartBrowsingForPeersWithError" object:nil userInfo:nil];
}

#pragma mark - MCSessionDelegate

-(void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    NSDictionary *dict = @{@"peerID": peerID,
                           @"state" : [NSNumber numberWithInt:state]
                           };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MPManager::didChangeState"
                                                        object:nil
                                                      userInfo:dict];
}

-(void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID{
    
//    NSLog(@"======= didReceiveData =======");
    
    NSDictionary *receivedDict = (NSDictionary*) [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSDictionary *dict = @{@"receivedDict": receivedDict,
                           @"peerID": peerID
                           };
//    NSLog(@"dict %@", dict);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MPManager::didReceiveData"
                                                        object:nil
                                                      userInfo:dict];
}


-(void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress{
    
}


-(void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error{
    
    if (error) {
        // alert
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MPManager::didFinishReceivingResource"
                                                        object:nil
                                                      userInfo:nil];
    
}

-(void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID{
    
}

@end
