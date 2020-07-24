//
//  LSCustomRequest.m
//  LSNetworkingModule
//
//  Created by ouhuowang on 2017/8/8.
//  Copyright © 2017年 ouhuowang. All rights reserved.
//

#import "LSCustomRequest.h"

@implementation LSCustomRequest

-(id)init
{
    if (self = [super init]) {
        self.method = HTTP_POST;
        self.requestId = -1;
        self.urlAppendingString = @"";
        
        self.baseRequestType = LSBaseRequestTypeCustom;
    }
    return self;
}

-(NSString *)requestUrl {
    return @"https://api.fitbit.com/1/user/5WZJNV/body/log/weight.json";
}

@end
