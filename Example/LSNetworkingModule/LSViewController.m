//
//  LSViewController.m
//  LSNetworkingModule
//
//  Created by ouhuowang on 01/10/2017.
//  Copyright (c) 2017 ouhuowang. All rights reserved.
//

#import "LSViewController.h"
#import <LSNetwork_iOS/LSNetworkingModule.h>
#import <LSNetwork_iOS/ServerCommunicationManager.h>
#import "LSCustomRequest.h"

@interface LSViewController ()

@end

@implementation LSViewController

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];
    [ServerCommunicationManager GetServerCommunication];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkchange:) name:LSNetworkingStatusChangeNotification object:nil];
    
    [ServerCommunicationManager startNetworkMonitoring];
    
    [[LSNetwokingURLCache shareInstance] setResourcesIdentifier:nil];
    
    [[LSNetwokingURLCache shareInstance] cacheResourcesFromThisURL:@"http://aasdzddid.com" resource:@{@"1":@2}];
    [[LSNetwokingURLCache shareInstance] cacheResourcesFromThisURL:@"http://aasssid.com" resource:@{@"1":@2}];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[LSNetwokingURLCache shareInstance] setResourcesIdentifier:@"345"];
        [[LSNetwokingURLCache shareInstance] cacheResourcesFromThisURL:@"http://aasdd.com" resource:@{@"1":@2}];
        [[LSNetwokingURLCache shareInstance] cacheResourcesFromThisURL:@"http://adasid.com" resource:@{@"1":@2}];
        [[LSNetwokingURLCache shareInstance] cacheResourcesFromThisURL:@"http://aasdzddid.com" resource:@{@"1":@1111}];
    });
//    [ServerCommunicationManager GetServerCommunication].networkStatusBlock = ^(AFNetworkReachabilityStatus status) {
//        
//    };
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"%@",[[LSNetwokingURLCache shareInstance] queryResourceFromThisURL:@"http://aasdzddid.com"]);
    });
    //这样用了了之后，上面的通知和成员block都不能用了
    [ServerCommunicationManager networkingStatusChange:^(NetworkStatus status) {
        NSLog(@"block status = %zd",status);
    }];
    
    BOOL networkSTatus = [ServerCommunicationManager isReachable];
    NSLog(@"networking status = %d",networkSTatus);
    
    NSLog(@"networking type = %d", [ServerCommunicationManager isReachableViaWiFi]);
    
    
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    /*
    NSString *link = @"http://360jq.jb51.net:81/201610/books/nessusshiyjiqiao_jb51.rar";
    NSString * cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *cachePath = [cacheDir stringByAppendingPathComponent:@"temp.rar"];
    [[ServerCommunicationManager GetServerCommunication] downloadWithUrl:link
                                                            saveFilePath:cachePath
                                                                progress:^(double progress) {
                                                                    NSLog(@"progress = %.2f", progress);
                                                                } success:^(NSURL *url) {
                                                                    NSLog(@"save url = %@", [url absoluteString]);
                                                                } failure:^(NSError *error) {
                                                                    NSLog(@"errr = %@", error);
                                                                }];
     */
    /*
    NSString *token = @"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI1V1pKTlYiLCJhdWQiOiIyMjhQOVYiLCJpc3MiOiJGaXRiaXQiLCJ0eXAiOiJhY2Nlc3NfdG9rZW4iLCJzY29wZXMiOiJ3aHIgd251dCB3cHJvIHdzbGUgd3dlaSB3c29jIHdzZXQgd2FjdCB3bG9jIiwiZXhwIjoxNTAyMjkzMDQzLCJpYXQiOjE1MDIyNjQyNDN9.f3dmhyHYKzrhiR4YZmfzq6s_VhQU3Egp5rFO8wl1iko";
    NSString *auth = [NSString stringWithFormat:@"Bearer %@", token];
    
    NSDictionary *customHeader = @{@"Authorization": auth};
    
    LSCustomRequest *request = [[LSCustomRequest alloc] init];
    request.httpHeader = customHeader;
    //[[ServerCommunicationManager GetServerCommunication] setCustomRequestHeader:customHeader];
    request.baseRequestType = LSBaseRequestTypeCustom;
    [request addStringValue:@"60" forKey:@"weight"];
    [request addStringValue:@"2017-08-11" forKey:@"date"];
    [request addStringValue:@"09:28:30" forKey:@"time"];
    
    [[ServerCommunicationManager GetServerCommunication] sendRequest:request
                                                              success:^(NSURLSessionDataTask *task, id responseObject) {
                                                                  NSLog(@"responseObj = %@", responseObject);
                                                              } failure:^(NSError *error) {
                                                                  NSLog(@"error %@", error);
                                                              }];
    
    */
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)networkchange:(NSNotification *)notification {
    NSNumber *statusObj = notification.object;
    NetworkStatus status = [statusObj integerValue];
    NSLog(@"status = %zd",status);
}

@end
