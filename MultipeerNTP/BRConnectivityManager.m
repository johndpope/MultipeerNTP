//
//  BRConnectivityManager.m
//  BRAudioSync
//
//  Created by Bektur Ryskeldiev on 3/29/14.
//  Copyright (c) 2014 Bektur Ryskeldiev. All rights reserved.
//

#import "BRConnectivityManager.h"
#import "BRAudioSyncConstants.h"
#import "NetworkClock.h"

@interface BRConnectivityManager () <MCSessionDelegate>
{
    MCPeerID  *_localPeerID;
    MCSession *_session;
    MCAdvertiserAssistant *_advertister;
    NSMutableArray *_connectedPeers;
}

- (instancetype)initWithDisplayName:(NSString *) name;

@end

@implementation BRConnectivityManager

#pragma mark - Initialization and setup

+ (BRConnectivityManager *)sharedInstance
{
    static BRConnectivityManager *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    
    
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[BRConnectivityManager alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    });
    return _sharedInstance;
}


- (instancetype)initWithDisplayName:(NSString *) name;
{
    self = [super init];
    if (self) {
        _localPeerID = [[MCPeerID alloc] initWithDisplayName:name];
        
        _session = [[MCSession alloc] initWithPeer:_localPeerID];
        _session.delegate = self;
        
        _connectedPeers = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Returning objects

- (MCBrowserViewController *)getBrowserViewControllerForServiceType:(NSString *) serviceType
                                                       withDelegate:(id<MCBrowserViewControllerDelegate>) delegate
{
    MCBrowserViewController *browser = [[MCBrowserViewController alloc] initWithServiceType:kServiceType session:_session];
    browser.delegate = delegate;
    return browser;
}

- (NSArray *)connectedPeers
{
    return [NSArray arrayWithArray:_connectedPeers];
}

#pragma mark - Advertising methods

- (void)startAdvertisingWithServiceType:(NSString *)serviceType
{
    if (!_advertister)
    {
        _advertister = [[MCAdvertiserAssistant alloc] initWithServiceType:serviceType discoveryInfo:nil session:_session];
    }
    [_advertister start];
}

- (void)stopAdvertising
{
    [_advertister stop];
}

#pragma mark - Session delegate methods

// Remote peer changed state
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    if (state == MCSessionStateConnected)
    {
        NSLog(@"Peer connected:%@", peerID.displayName);
        [_connectedPeers addObject:peerID];
    }
    else if (state == MCSessionStateConnecting)
    {
        NSLog(@"Peer connecting:%@", peerID.displayName);
    }
    else if (state == MCSessionStateNotConnected)
    {
        NSLog(@"Peer disconnected:%@", peerID.displayName);
        [_connectedPeers removeObject:peerID];
    }
}

// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    NSDate *receivingTime = [NSDate date];
    NSDate *receivingNTPTime = [[NetworkClock sharedInstance] networkTime];
    NSError *error = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    
    if (error == nil)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationMessageReceived
                                                            object:nil
                                                          userInfo:@{kNotificationMessageDictKey : jsonDict,
                                                                     kNotificationMessageTimeKey : receivingTime,
                                                                     kNotificationMessageNTPTimeKey: receivingNTPTime}];
    }
    else
    {
        NSLog(@"Error parsing json: %@", error.description);
    }
}

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    
}

// Start receiving a resource from remote peer
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    
}

// Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    
}

#pragma mark - Streaming

- (void)sendOutputStream:(NSOutputStream *) stream toPeer:(MCPeerID *)peer
{
    
}

#pragma mark - Sending messages

- (void)sendMessage: (NSString *) message
    withNetworkTime: (NSDate *) networkTime
{
    NSDictionary *messageDictionary = @{kMessageNetworkTimeKey: [NSNumber numberWithDouble:[networkTime timeIntervalSince1970]],
                                        kMessageDeviceTimeKey:  [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]],
                                        kMessageCommandKey:     message};
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:messageDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error == nil)
    {
        if (![_session sendData:jsonData
                        toPeers:_connectedPeers
                       withMode:MCSessionSendDataReliable
                          error:&error])
        {
            NSLog(@"%@ message sending error: %@", message, error.description);
        }
    }
    else
    {
        NSLog(@"JSON error: %@", error.description);
    }
}



@end
