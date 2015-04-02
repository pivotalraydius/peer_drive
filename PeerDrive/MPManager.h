//
//  MPManager.h
//  MPTest
//
//  Created by Rayser on 24/4/14.
//  Copyright (c) 2014 Herenow. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MPManager : NSObject <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCAdvertiserAssistantDelegate> {

    NSArray *ArrayInvitationHandler;
}

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) MCAdvertiserAssistant *advertiserAssistant;
@property (nonatomic, strong) NSString *serviceType;



-(void)setupPeerAndSessionWithDisplayName:(NSString *)displayName serviceType:(NSString*)serviceType;

-(void)browsePeers;
-(void)advertiseSelf:(BOOL)shouldAdvertise withDiscoveryInfo:(NSDictionary*)discoveryInfo;
-(void)stopAdvertising;
-(void)stopBrowsing;

@end
