//
//  ServerCommunicationManager.m
//  TestProject_Example
//
//  Created by pengpeng on 2020/5/21.
//  Copyright © 2020 pengpeng. All rights reserved.
//

#import "ServerCommunicationManager.h"
#import <SystemConfiguration/SCNetworkReachability.h>       // 用于网络状态判断
#import "ProtocolSimulator.h"
#import "BaseNetworkError.h"
#import "HttpErrcode.h"
#import "ServerComunicationManagerInternal.h"
#import "LSNetwokingURLCache.h"

#define  kTestHttpHostStr   @"sports.lifesense.com"         // 用于测试网络状态

#define _ServerCommunicationManager_isolation_Begin             \
__weak typeof(self) weakSelf = self; \
[self asyncBlock :^{__strong ServerCommunicationManager *sself = weakSelf;           \
if (sself) {

#define _ServerCommunicationManager_isolation_End \
}                      \
}];

typedef void(^UploadFileProgress)(double progress);

@interface ServerCommunicationManager () <NSURLSessionDownloadDelegate, NSURLSessionTaskDelegate> {
    BOOL _isProtocolSimulatorAvailable;
}

@property (nonatomic,retain) ProtocolSimulator *protoctolSimulator;

@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfig;
@property (nonatomic, strong) NSURLSession *uploadDownloadSession;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionTask *> *sendedTaskDict;

//@property (nonatomic, copy) UploadFileProgress uploadProgress;

@property (nonatomic, strong) NSMutableDictionary *uploadProgressBlockDic;

@property (nonatomic, strong) NSDictionary *headerDic;


@end

@implementation ServerCommunicationManager

+ (id<ServerCommunicationProtocol>)GetServerCommunication {
    static __strong ServerCommunicationManager *serverCommunicationManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serverCommunicationManager = [[ServerCommunicationManager alloc] init];
        
//        serverCommunicationManager.httpSessionManager = [AFHTTPSessionManager manager];
//        serverCommunicationManager.httpSessionManager.completionQueue = serverCommunicationManager.callbackQueue;
//
//        AFJSONResponseSerializer *serializerResponse = [AFJSONResponseSerializer serializer];
//        serializerResponse.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html",@"text/plain", nil];
//        serverCommunicationManager.httpSessionManager.responseSerializer = serializerResponse;
//        AFJSONRequestSerializer *serializer = [AFJSONRequestSerializer serializer];
//        //[serializer setValue:@"application/x-www-form-urlencoded;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
//        serializer.timeoutInterval = 30.0f;
//        serverCommunicationManager.httpSessionManager.requestSerializer = serializer;
//
//        //customManager------------------------
//        serverCommunicationManager.customSessionManager = [AFHTTPSessionManager manager];
//        serverCommunicationManager.customSessionManager.completionQueue = serverCommunicationManager.callbackQueue;
//
//        AFHTTPRequestSerializer *customRequestSerializer = [AFHTTPRequestSerializer serializer];
//        customRequestSerializer.timeoutInterval = 30.0f;
//        serverCommunicationManager.customSessionManager.requestSerializer = customRequestSerializer;
//
        
    });
    return serverCommunicationManager;
}


- (id)init {
    self = [super init];
    if (self) {
        _sendedTaskDict = [[NSMutableDictionary alloc] init];
        _callbackQueue = dispatch_get_main_queue();
        _isProtocolSimulatorAvailable = NO;
        
        _isolationQueueLabel = @"com.ServerCommunicationManager.isolationQueue";
        _isolationQueue = dispatch_queue_create([_isolationQueueLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_get_main_queue();
        
        [self addNetworkingStatusChange];
    }
    return self;
}

- (void)addNetworkingStatusChange {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
      self.reachability = [LSReachability reachabilityWithHostName:kTestHttpHostStr];
      [self.reachability startNotifier];
}

- (void)reachabilityChanged:(NSNotification *)note {
    LSReachability* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass:[LSReachability class]]);
    NetworkStatus netStatus = [curReach currentReachabilityStatus];
    [[NSNotificationCenter defaultCenter] postNotificationName:LSNetworkingStatusChangeNotification object:[NSNumber numberWithInteger:netStatus]];
    switch (netStatus) {
        case NotReachable:{ // 网络不能使用
            
            break;
        }
        case ReachableViaWWAN:{ // 使用的数据流量
            
            break;
        }
        case ReachableViaWiFi:{ // 使用的 WiFi
            
            break;
        }
        default: {
            
            break;
        }
    }
}

- (NSString *)generateRequestId {
    return [[NSUUID UUID] UUIDString];
}

- (void)asyncBlock:(void (^)(void))block {
    dispatch_async(self.isolationQueue, block);
}

-(NSMutableDictionary*)_generateParamsDict:(LSBaseRequest*)request
{
    NSMutableDictionary* ret = request.dataDict;
    return ret;
}

- (NSURLSession *)uploadDownloadSession {
    if (!_uploadDownloadSession) {
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 5;
        _uploadDownloadSession = [NSURLSession sessionWithConfiguration:self.sessionConfig delegate:self delegateQueue:queue];
    }
    return _uploadDownloadSession;
}

- (NSURLSessionConfiguration *)sessionConfig {
    if (!_sessionConfig) {
        _sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        _sessionConfig.timeoutIntervalForRequest = 30.0f;
    }
    return _sessionConfig;
}

-(ProtocolSimulator *)protoctolSimulator{
    if (!_protoctolSimulator) {
        _protoctolSimulator = [[ProtocolSimulator alloc] init];
    }
    return _protoctolSimulator;
}

- (ProtocolSimulator *)getProtocolSimulator {
    if (!_protoctolSimulator) {
        _protoctolSimulator = [[ProtocolSimulator alloc] init];
    }
    return _protoctolSimulator;
}

- (NSMutableDictionary *)uploadProgressBlockDic {
    if (!_uploadProgressBlockDic) {
        _uploadProgressBlockDic = [[NSMutableDictionary alloc] init];
    }
    return _uploadProgressBlockDic;
}


/**
 *  添加自定义的http header,
 *  参数：header NSDictionary<NSString *, NSString *> *header
 */
-(void)setCustomRequestHeader:(NSDictionary<NSString *, NSString *> *)header {
    self.headerDic = header;
}

-(void)clearCustomRequestHeader {
    self.headerDic = nil;
}

- (void)setHeaderForRequest:(NSMutableURLRequest *)request {
    NSArray *allkeys = [self.headerDic allKeys];
    for (NSString *key in allkeys) {
        NSString *val = [self.headerDic objectForKey:key];
        [request addValue:val forHTTPHeaderField:key];
    }
}

- (NSURLSessionDataTask *)requestWithMethod:(NSString *)method
                         requestSessionType:(LSBaseRequestType)requestType
                                  URLString:(NSString *)URLString
                                 parameters:(NSDictionary *)parameters
                                    success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                    failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure  {
    
    // Handle Common Mission, Cache, Data Reading & etc.
    void (^responseHandleBlock)(NSURLSessionDataTask *task, id responseObject) = ^(NSURLSessionDataTask *task, id responseObject) {
        success(task, responseObject);
    };
    
    
    NSURLSessionDataTask *task = nil;
    NSString *methodStr = [method uppercaseString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
    request.HTTPMethod = methodStr;
    if ([methodStr isEqualToString:@"POST"]) {
        NSError * error = nil;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&error];
        request.HTTPBody = jsonData;
    }
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    [mutableRequest setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [self setHeaderForRequest:mutableRequest];
    request = [mutableRequest copy];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:self.sessionConfig];
    
    // 通过request初始化task
    task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            id responseObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            NSLog(@"%@", responseObject);
            responseHandleBlock(task, responseObject);
        } else {
            failure(task,error);
        }
    }];
    // 创建的task是停止状态，需要我们去启动
    [task resume];
    
    return task;
}

-(LSBaseResponse*) responseFromRequest:(LSBaseRequest*)request  ResponseData:(NSData*)responseData
{
    LSBaseResponse *response = nil;
    NSString *responseName = request.responseName;
    
    if (responseName == nil || responseName.length <= 0)
    {
    }
    else
    {
        response = [self getResponseInstanceFromResponseName:responseName];
        response.data = responseData;
    }
    
    if (response == nil) {
        response = [[LSBaseResponse alloc] init];
        response.data = responseData;
        response.ret = RET_DEFAULT_ERROR;
        response.error = [BaseNetworkError errorWithHttpStatusCode:kHttpStatusCodeSucceedOK serverReturnValue:RET_DEFAULT_ERROR serverErrorCode:0 serverErrorType:RESPONSE_TYPE_NOFOUND serverErrorMsg:@""];
    }
    response.request = request;
    return response;
}

-(LSBaseResponse*) getResponseInstanceFromResponseName:(NSString *)responseName
{
    LSBaseResponse *response = nil;
    
    NSString *responseClassName = responseName;
    if (responseClassName)
    {
        response = [[NSClassFromString(responseClassName) alloc] init];
    }
    
    if(responseClassName==nil || response==nil)
    {
        NSLog(@"%@ %@",NSStringFromClass(self.class), @"responseClassName or response is nil");
    }

    return response;
}

- (void)tryParseResponseData:(LSBaseResponse *)response {
    @try{
        [response parse];
    }
    @catch(NSException* e)
    {
        response.ret = RESPONSE_PARSE_ERROR;
        NSLog(@"Parse response %@",[NSString stringWithFormat:@"%@_%@",@"!!!json解析异常!!!/n",e.reason]);
    }
}

#pragma mark - cache task
- (void)cacheTask:(NSURLSessionTask *)task requestId:(NSString *)requestId {
    if (task && requestId) {
        [self.sendedTaskDict setObject:task forKey:requestId];
    }
}

- (NSURLSessionTask *)removeTaskForRequestId:(NSString *)requestId {
    if (requestId == nil) return nil;
    NSURLSessionTask *task = [self.sendedTaskDict objectForKey:requestId];
    return task;
}

#pragma mark - - public
/*
 判断网络是否在线
 */
+ (BOOL)isReachable {
//    LSReachability *reachability = [LSReachability reachabilityWithHostName:kTestHttpHostStr];
    
    ServerCommunicationManager *manger = (ServerCommunicationManager *)[ServerCommunicationManager GetServerCommunication];
    return  [manger.reachability isReachable];
}

+ (BOOL)isReachableViaWWAN {
    ServerCommunicationManager *manger = (ServerCommunicationManager *)[ServerCommunicationManager GetServerCommunication];
    return  [manger.reachability isReachableViaWWAN];
}

+ (BOOL)isReachableViaWiFi {
    ServerCommunicationManager *manger = (ServerCommunicationManager *)[ServerCommunicationManager GetServerCommunication];
    return  [manger.reachability isReachableViaWiFi];
}

+ (void)startNetworkMonitoring {
    ServerCommunicationManager *manger = (ServerCommunicationManager *)[ServerCommunicationManager GetServerCommunication];
    return [manger addNetworkingStatusChange];
}

+ (void)stopNetworkMonitoring {
    ServerCommunicationManager *manger = (ServerCommunicationManager *)[ServerCommunicationManager GetServerCommunication];
    return [manger.reachability stopNotifier];
}

+(void)networkingStatusChange:(void (^)(NetworkStatus status))networkChangeblock {
    if (networkChangeblock) {
        ServerCommunicationManager *manger = (ServerCommunicationManager *)[ServerCommunicationManager GetServerCommunication];
        networkChangeblock([manger.reachability currentReachabilityStatus]);
    }
}

/**
 *  发送请求，线程安全
 *
 *  参数：request 请求对象
 *
 *  返回：请求Id
 */
#pragma mark - 非Block请求
- (NSString *)sendRequest:(LSBaseRequest*)request {
    if (!request) {
        return nil;
    }
    NSString * requestId = [self generateRequestId];
    [request appendRequestId:requestId];
    [request generateRequestToken];
    NSString *urlWithParams = [request mergeUrlParameters];
    
    NSURLSessionDataTask *task = nil;
    NSDictionary *params = [self _generateParamsDict:request];
    
    if ([request.httpHeader count] > 0) {
        [self clearCustomRequestHeader];
        
        [self setCustomRequestHeader:request.httpHeader];
        request.baseRequestType = LSBaseRequestTypeCustom;
    }
    
    task = [self requestWithMethod:request.method
                requestSessionType:request.baseRequestType
                         URLString:urlWithParams
                        parameters:params
                           success:^(NSURLSessionDataTask *task, id responseObject) {
                               [self onRequestFinish:request data:responseObject];
                           } failure:^(NSURLSessionDataTask *task, NSError *error) {
                               [self onRequestFail:request responseStatusCode:error.code withError:error];
                           }];
    [self cacheTask:task requestId:requestId];
    return requestId;
}

- (NSString *)sendRequest:(LSBaseRequest *)request
                  success:(void (^)(NSURLSessionDataTask * _Nullable task, id responseObject))success
                  failure:(void (^)(NSError *error))failure {
    return [self sendRequest:request
        completeWithResponse:^(NSURLSessionDataTask *task, LSBaseResponse *response) {
            success == nil ?: success(task, response.data);
        }
         failureWithResponse:^(NSURLSessionDataTask *task, LSBaseResponse *response) {
             failure == nil ?: failure(response.nsError);
         }];
}

- (NSString *)sendRequest:(LSBaseRequest *)request
                 complete:(void (^)(NSInteger code, NSString *message, id responseData))completeBlock
                  failure:(void (^)(NSError *error))failureBlock {
    
    return [self sendRequest:request
        completeWithResponse:^(NSURLSessionDataTask * _Nullable task, LSBaseResponse *response) {
            completeBlock == nil ?: completeBlock([[response.data objectForKey:@"code"] integerValue], [response.data objectForKey:@"msg"], [response.data objectForKey:@"data"]);
        } failureWithResponse:^(NSURLSessionDataTask *task, LSBaseResponse *response) {
            failureBlock == nil ?: failureBlock(response.nsError);
        }];;
}

- (NSString *)sendRequest:(LSBaseRequest *)request
     completeWithResponse:(void (^)( NSURLSessionDataTask * _Nullable task, LSBaseResponse *response))completeBlock
                  failureWithResponse:(void (^)(NSURLSessionDataTask *task, LSBaseResponse *response))failureBlock {
    NSString * requestId = [self generateRequestId];
    [request appendRequestId:requestId];
    [request generateRequestToken];
    NSString *urlWithParams = [request mergeUrlParameters];

    NSURLSessionDataTask *task = nil;
    NSDictionary *params = [self _generateParamsDict:request];
    //自定义的头需要重新设置
    if ([request.httpHeader count] > 0) {
        [self clearCustomRequestHeader];
        [self setCustomRequestHeader:request.httpHeader];
        request.baseRequestType = LSBaseRequestTypeCustom;
    }
    
    task = [self requestWithMethod:request.method
                requestSessionType:request.baseRequestType
                         URLString:urlWithParams
                        parameters:params
                           success:^(NSURLSessionDataTask *task, id responseObject) {
                               LSBaseResponse *response = [self responseFromRequest:request ResponseData:responseObject];
                               [self tryParseResponseData:response];
                               
                               if (response.ret == RET_SUCCESS) {
                                   if ([response checkParsingVadility]) {
                                       //退出登录或者token失效检测在 onRequestCompleteWithReposeCode 处理。自己实现
                                       if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestSucceed:didReceiveResponse:)]) {
                                           [self.eventsDelegate communicationManager:(id)self
                                                                  sendRequestSucceed:request
                                                                  didReceiveResponse:response];
                                       }
                                       
                                       completeBlock == nil ?: completeBlock(task, response);
                                   } else {
                                       NSString *dataExpeStr = @"数据异常";
                                       response.ret = RESPONSE_DATA_INVALID;
                                       response.statusCode = -1;
                                       response.msg = dataExpeStr;
                                       response.nsError = [NSError errorWithDomain:@"com.lifesense.LSNetworking"
                                                                              code:-1
                                                                          userInfo:@{
                                                                                     @"msg" : dataExpeStr
                                                                                     }];
                                       
                                       if ([self.eventsDelegate respondsToSelector:@selector(communicationManager:didReceiveInvalidDataResponse:)]) {
                                           [self.eventsDelegate communicationManager:(id)self
                                                       didReceiveInvalidDataResponse:response];
                                       }
                                       
                                       if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                                           [self.eventsDelegate communicationManager:(id)self
                                                                   sendRequestFailed:request
                                                                            response:response];
                                       }
                                       failureBlock == nil ?: failureBlock(task, response);
                                   }
                               } else {
                                   //退出登录或者token失效检测在 onRequestCompleteWithReposeCode 处理。自己实现
                                   if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestSucceed:didReceiveResponse:)]) {
                                       [self.eventsDelegate communicationManager:(id)self
                                                              sendRequestSucceed:request
                                                              didReceiveResponse:response];
                                   }
                                   completeBlock == nil ?: completeBlock(task, response);
                               }
                               if (request.needsCacheResponse && responseObject && responseObject[@"code"]) {
                                   if ([responseObject[@"code"] intValue] == 200) {
                                       @try {
                                           [[LSNetwokingURLCache shareInstance] cacheResourcesFromThisURL:urlWithParams resource:responseObject];
                                       } @catch (NSException *exception) {
                                           NSLog(@"缓存数据失败%@",exception.description);
                                       } @finally {
                                           
                                       }
                                       
                                   }
                               }
                               
                           } failure:^(NSURLSessionDataTask *task, NSError *error) {
                               LSBaseResponse *response = [self responseFromRequest:request ResponseData:nil];
                               [self setUpErrorMessageToResponse:response responseStatusCode:error.code withError:error];
                               
                               if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                                   [self.eventsDelegate communicationManager:(id)self
                                                           sendRequestFailed:request
                                                                    response:response];
                               }
                               failureBlock == nil ?: failureBlock(task, response);
                           }];
    [self cacheTask:task requestId:requestId];
    
    if (request.needsCacheResponse) {
        [[LSNetwokingURLCache shareInstance] resourceOfThisURL:urlWithParams completeHandler:^(LSNetwokingURLResource * _Nonnull urlResource) {
            LSBaseResponse *response = [self responseFromRequest:request ResponseData:urlResource.resource];
            [self tryParseResponseData:response];
            if (urlResource.resource && completeBlock) {
                completeBlock(nil,response);
            }
        }];
    }
    return requestId;
}

//upload file
- (NSString *)uploadFileWithUrl:(NSString *)urlString
                      withParam:(NSDictionary *)params
                   uploadedData:(NSData *)updata
           upLoadedSaveFileName:(NSString *)filename
                       progress:(void (^)(double progress))progress
                        success:(void (^)(NSInteger code, NSString *msg, id responseData))success
                        failure:(void (^)(NSError *error))failureBlock {
    
    
    NSString *requestId = [self generateRequestId];
    
    _ServerCommunicationManager_isolation_Begin
    
    NSOperationQueue *queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 5;
    
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/json;text/json;text/javascript;text/html;text/plain;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [self setHeaderForRequest:request];
    request.HTTPMethod = @"POST";
    
    NSURLSessionUploadTask *uploadTask = [self.uploadDownloadSession uploadTaskWithRequest:request fromData:updata completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (failureBlock) {
                NSString *netExceptionStr = @"网络异常,请稍后再试";
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:netExceptionStr forKey:NSLocalizedDescriptionKey];
                NSError *redefineError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
                failureBlock(redefineError);
            }
        } else {
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            
            NSString *responseMsg = [responseDict objectForKey:@"msg"];
            NSInteger responseCode = [[responseDict objectForKey:@"code"] integerValue];
            id resultData = [responseDict objectForKey:@"data"];
            if (success) {
                success(responseCode, responseMsg, resultData);
            }
        }
    }];
    
    [self.uploadProgressBlockDic setValue:progress forKey:@(uploadTask.taskIdentifier).stringValue];
    
    [uploadTask resume];
    
    [sself cacheTask:uploadTask requestId:requestId];
    
    _ServerCommunicationManager_isolation_End
    return requestId;
}

- (NSString *)uploadFileWithRequest:(LSBaseRequest *)request
                                     uploadedData:(NSData *)updata
                             upLoadedSaveFileName:(NSString *)filename
                                         progress:(void (^)(double progress))progress
                                          success:(void (^)(NSInteger code, NSString *msg, id responseData))success
                                          failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failureBlock {
    NSString * requestId = [self generateRequestId];
    [request appendRequestId:requestId];
    [request generateRequestToken];
    NSString *urlWithParams = [request mergeUrlParameters];

    NSDictionary *params = [self _generateParamsDict:request];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlWithParams]];
    urlRequest.HTTPMethod = @"POST";
    NSError * error = nil;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&error];
    urlRequest.HTTPBody = jsonData;

    NSMutableURLRequest *mutableRequest = [urlRequest mutableCopy];
    [mutableRequest setValue:@"application/json;text/json;text/javascript;text/html;text/plain;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [self setHeaderForRequest:mutableRequest];
    urlRequest = [mutableRequest copy];
        
        
    NSURLSessionUploadTask *uploadTask = [self.uploadDownloadSession uploadTaskWithRequest:urlRequest fromData:updata completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        LSBaseResponse *responseData = [self responseFromRequest:request ResponseData:data];
        if (error) {
            [self setUpErrorMessageToResponse:responseData responseStatusCode:error.code withError:error];
        } else {
            [self tryParseResponseData:responseData];
        }
        
        if (error) {
            if (failureBlock){
                if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                    [self.eventsDelegate communicationManager:(id)self sendRequestFailed:request response:responseData];
                }
                failureBlock(nil, responseData.nsError);
            }
        } else {
            
            if (responseData.ret == RET_SUCCESS) {
                if ([responseData checkParsingVadility]) {
                    //退出登录或者token失效检测在 onRequestCompleteWithReposeCode 处理。自己实现
                    if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestSucceed:didReceiveResponse:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                               sendRequestSucceed:request
                                               didReceiveResponse:responseData];
                    }
                    
                    if (success) {
                        success([[responseData.data objectForKey:@"code"] integerValue], [responseData.data objectForKey:@"msg"], [responseData.data objectForKey:@"data"]);
                    }
                    
                } else {
                    responseData.ret = RESPONSE_DATA_INVALID;
                    responseData.statusCode = -1;
                    responseData.msg = @"数据异常";
                    
                    if ([self.eventsDelegate respondsToSelector:@selector(communicationManager:didReceiveInvalidDataResponse:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                    didReceiveInvalidDataResponse:responseData];
                    }
                    
                    if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                                sendRequestFailed:request
                                                         response:responseData];
                    }
                    failureBlock == nil ?: failureBlock(nil, responseData.nsError);
                }
            } else {
                //退出登录或者token失效检测在 onRequestCompleteWithReposeCode 处理。自己实现
                if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestSucceed:didReceiveResponse:)]) {
                    [self.eventsDelegate communicationManager:(id)self
                                           sendRequestSucceed:request
                                           didReceiveResponse:responseData];
                }
                
                if (success) {
                    success([[responseData.data objectForKey:@"code"] integerValue], [responseData.data objectForKey:@"msg"], [responseData.data objectForKey:@"data"]);
                }
            }
        }
        
    }];
    
    [self.uploadProgressBlockDic setValue:progress forKey:@(uploadTask.taskIdentifier).stringValue];
    [uploadTask resume];
    
    [self cacheTask:uploadTask requestId:requestId];
    
    return requestId;
}

- (NSString *)downloadWithUrl:(NSString *)urlStr
                 saveFilePath:(NSString *)savePath
                     progress:(void (^)(double progress))progress
                      success:(void (^)(NSURL *url))success
                      failure:(void (^)(NSError *error))fail {
    
    NSString *requestId = [self generateRequestId];
    
    _ServerCommunicationManager_isolation_Begin
    NSURL *url = [NSURL URLWithString:urlStr];
        
    NSURLSessionDownloadTask *downloadTask = [self.uploadDownloadSession downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
//            NSString *fullPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:response.suggestedFilename];
            [[NSFileManager defaultManager]moveItemAtURL:location toURL:[NSURL fileURLWithPath:savePath] error:nil];
            //下载完成
            if (success) {
                success([NSURL fileURLWithPath:savePath]);
            }
        }
        else{
            
            //下载失败
            //NSLog(@"%@",error);
            //NSString *netExceptionStr = @"网络异常,请稍后再试";
            NSString *netExceptionStr = @"网络异常,请稍后再试";
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:netExceptionStr                                                                      forKey:NSLocalizedDescriptionKey];
            NSError *redefineError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
            if (fail) {
                fail(redefineError);
            }
        }
    }];
    [self.uploadProgressBlockDic setValue:progress forKey:@(downloadTask.taskIdentifier).stringValue];
    
    [downloadTask resume];
    [sself cacheTask:downloadTask requestId:requestId];
    _ServerCommunicationManager_isolation_End
    return requestId;
}

#pragma mark - 新的上传和下载，使用 LSBaseRequest 和 LSBaseResponse, 20170726
/**
 *  上传文件
 *  参数：request 为上传地址url的封装，和 普通的 LSBaseRequest 一样，其中，二进制文件保存在 LSBaseRequest.binaryDataArray  里面
 *  LSBaseRequest.binaryDataArray 里面保存的每个对象都是NSDictionary,
 *  具体用法请仔细阅读和查看 addBinaryData:(NSData *)updata withFileName:(NSString *)upfilename 函数
 *  注意：progress(double progress) 进度条回调block, double progress是进度 注意，这个数值 已经 乘以 100
 
 */
- (NSString *)uploadWithRequest:(LSBaseRequest *)request
                       progress:(void (^)(double progress))progress
                      completed:(void (^)(NSURLSessionDataTask *task, LSBaseResponse *response))completeBlock {
    NSString *requestId = [self generateRequestId];
    
    _ServerCommunicationManager_isolation_Begin
    if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(serverCommunicationManager:shouldSendRequest:)]) {
        BOOL sendFlag = [self.eventsDelegate serverCommunicationManager:(id)self shouldSendRequest:request];
        if (!sendFlag) {
            return;
        }
    }
    
    NSString* urlString = request.requestUrl;
    
    NSString *paramstr = request.urlAppendingString;
    
    NSString *qmakrstr = @"?";
    NSRange qmarkRang = [urlString rangeOfString:qmakrstr];
    NSRange pmarkRang = [paramstr rangeOfString:qmakrstr];
    if (qmarkRang.location != NSNotFound && pmarkRang.location != NSNotFound) {
        paramstr = [paramstr stringByReplacingOccurrencesOfString:qmakrstr withString:@"&"];
        urlString = [urlString stringByAppendingString:paramstr];
    }
    else {
        urlString = [urlString stringByAppendingString:paramstr];
    }
    
    NSDictionary *params = [self _generateParamsDict:request];
    
    if ([request.binaryDataArray count]<=0) {
        NSLog(@"上传的内容为空~~！！！");
        return;
    }
    
    NSDictionary *upfileInfoDict = [request.binaryDataArray objectAtIndex:0];
    if (![upfileInfoDict isKindOfClass:[NSDictionary class]]) {
        NSLog(@"上传的数据设置格式不正确~~！！！");
        return;
    }
    
        
    NSData *updata = [upfileInfoDict objectForKey:BIANRY_DATA_KEY];
//    NSString *filename = [upfileInfoDict objectForKey:FILENAME_KEY];
        
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    urlRequest.HTTPMethod = @"POST";
    NSMutableString *bodyStr = [[NSMutableString alloc] initWithCapacity:0];
    for (NSString *keyStr in params.allKeys) {
       if (bodyStr.length > 0) {
           [bodyStr appendString:@"&"];
       }
       [bodyStr appendFormat:@"%@=%@", keyStr, [params objectForKey:keyStr]];
    }
    urlRequest.HTTPBody = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableURLRequest *mutableRequest = [urlRequest mutableCopy];
    [mutableRequest setValue:@"application/json;text/json;text/javascript;text/html;text/plain;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [self setHeaderForRequest:mutableRequest];
    urlRequest = [mutableRequest copy];
    
    
    NSURLSessionUploadTask *uploadTask = [self.uploadDownloadSession uploadTaskWithRequest:urlRequest fromData:updata completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        LSBaseResponse *resultResponse = [self responseFromRequest:request ResponseData:data];
        
        if (error) {
            [self setUpErrorMessageToResponse:resultResponse responseStatusCode:error.code withError:error];
            
            if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                [self.eventsDelegate communicationManager:(id)self sendRequestFailed:request response:resultResponse];
            }
            
            if (completeBlock) {
                completeBlock(nil, resultResponse);
            }
        } else {
            
            [self tryParseResponseData:resultResponse];
            
            if (resultResponse.ret == RET_SUCCESS) {
                if ([resultResponse checkParsingVadility]) {
                    //退出登录或者token失效检测在 onRequestCompleteWithReposeCode 处理。自己实现
                    if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestSucceed:didReceiveResponse:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                               sendRequestSucceed:request
                                               didReceiveResponse:resultResponse];
                    }
                    
                    if (completeBlock) {
                        completeBlock(nil, resultResponse);
                    }
                    
                } else {
                    NSString *dataExpStr = @"数据异常";
                    resultResponse.ret = RESPONSE_DATA_INVALID;
                    resultResponse.statusCode = -1;
                    resultResponse.msg = dataExpStr;
                    
                    if ([self.eventsDelegate respondsToSelector:@selector(communicationManager:didReceiveInvalidDataResponse:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                    didReceiveInvalidDataResponse:resultResponse];
                    }
                    
                    if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                                sendRequestFailed:request
                                                         response:resultResponse];
                    }
                    if (completeBlock) {
                        completeBlock(nil, resultResponse);
                    }
                }
            } else {
                //退出登录或者token失效检测在 onRequestCompleteWithReposeCode 处理。自己实现
                if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestSucceed:didReceiveResponse:)]) {
                    [self.eventsDelegate communicationManager:(id)self
                                           sendRequestSucceed:request
                                           didReceiveResponse:resultResponse];
                }
                
                if (completeBlock) {
                    completeBlock(nil, resultResponse);
                }
            }

        }
        
    }];
    [self.uploadProgressBlockDic setValue:progress forKey:@(uploadTask.taskIdentifier).stringValue];
    
    [uploadTask resume];

    [sself cacheTask:uploadTask requestId:requestId];
    _ServerCommunicationManager_isolation_End;
    return requestId;
}

/**
 *  下载文件
 *  参数：request 为上传地址url的封装，和 普通的 LSBaseRequest 一样。
 *  参数：saveFilePath, 保存路径.没有找到 saveFilePath的保存路径或者属性。暂时多加一个参数
 *  参数：下载保存成功返回的路径（saveFilePath），以id data的形式返回保存的路径,LSBaseResponse.data to NSString
 *  注意：progress(double progress) 进度条回调block, double progress是进度 注意，这个数值 已经 乘以 100
 */
- (NSString *)downloadWithRequest:(LSBaseRequest *)request
                     saveFilePath:(NSString *)savePath
                         progress:(void (^)(double progress))progress
                        completed:(void (^)(NSURLSessionDataTask *task, LSBaseResponse *response))completeBlock {
    NSString *requestId = [self generateRequestId];
    
    
    
    _ServerCommunicationManager_isolation_Begin
    
    NSString* urlString = request.requestUrl;
    
    NSString *paramstr = request.urlAppendingString;
    
    NSString *qmakrstr = @"?";
    NSRange qmarkRang = [urlString rangeOfString:qmakrstr];
    NSRange pmarkRang = [paramstr rangeOfString:qmakrstr];
    if (qmarkRang.location != NSNotFound && pmarkRang.location != NSNotFound) {
        paramstr = [paramstr stringByReplacingOccurrencesOfString:qmakrstr withString:@"&"];
        urlString = [urlString stringByAppendingString:paramstr];
    }
    else {
        urlString = [urlString stringByAppendingString:paramstr];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
        
    NSURLSessionDownloadTask *downloadTask = [self.uploadDownloadSession downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        LSBaseResponse *resultResponse = [[LSBaseResponse alloc] init];
        if (!error) {
//            NSString *fullPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:response.suggestedFilename];
            [[NSFileManager defaultManager]moveItemAtURL:location toURL:[NSURL fileURLWithPath:savePath] error:nil];
            //下载完成
            NSString *downSuccStr = @"下载成功";
            resultResponse.ret = RET_SUCCESS;
            resultResponse.statusCode = 200;
            resultResponse.msg = downSuccStr;
            
            NSData *savepathData = [savePath dataUsingEncoding:NSUTF8StringEncoding];
            resultResponse.data = savepathData;
        } else{
            
            NSString *downFaildStr = @"下载失败";
            resultResponse.ret = RESPONSE_DATA_INVALID;
            resultResponse.statusCode = -1;
            resultResponse.msg = downFaildStr;
        }
        completeBlock(nil, resultResponse);
    }];

    [self.uploadProgressBlockDic setValue:progress forKey:@(downloadTask.taskIdentifier).stringValue];
    [downloadTask resume];
    [sself cacheTask:downloadTask requestId:requestId];
    _ServerCommunicationManager_isolation_End
    return requestId;
}

- (void)cancelRequestWithRequestId:(NSString *)requestId {
    
    _ServerCommunicationManager_isolation_Begin
    NSURLSessionTask *task = [self removeTaskForRequestId:requestId];
    if (task) {
        [task cancel];
    }
    _ServerCommunicationManager_isolation_End
}


- (void)setProtocolSimulatorAvailable:(BOOL)available {
    _isProtocolSimulatorAvailable = available;
}

- (BOOL)isProtocolSimulatorAvailable {
    return _isProtocolSimulatorAvailable;
}


#pragma mark - 上传进度代理方法  NSURLSessionTaskDelegate
// 上传进度
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    UploadFileProgress progress = [self.uploadProgressBlockDic objectForKey:@(task.taskIdentifier)];
    if (progress) {
        progress(100.0 * totalBytesSent / totalBytesExpectedToSend);
    }
    [self.uploadProgressBlockDic removeObjectForKey:@(task.taskIdentifier)];
}
 
// 上传完成
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
}


#pragma mark - - 下载进度代理方法 NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    
}

// 进度
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    UploadFileProgress progressBlock = [self.uploadProgressBlockDic objectForKey:@(downloadTask.taskIdentifier)];
    if (progressBlock) {
        double progress = 100.0 * totalBytesWritten / totalBytesExpectedToWrite;
        progressBlock(progress);
    }
    [self.uploadProgressBlockDic removeObjectForKey:@(downloadTask.taskIdentifier)];
}

// 断点续传
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                      didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes {
    
}



#pragma mark - 处理请求成功失败

- (void)onRequestFinish:(LSBaseRequest *)request data:(NSData*)data
{
    dispatch_async(self.isolationQueue, ^{
        
        //ADD BY ROLAND
        LSBaseResponse* response = [self responseFromRequest:request ResponseData:data];
        [self tryParseResponseData:response];
    
        
        if(response.ret == RET_SUCCESS) {
            
            if (![response checkParsingVadility]) {
                response.ret = RESPONSE_DATA_INVALID;
                response.statusCode = -1;
                response.msg = @"数据异常";
            } else {
                response.error = nil;
                dispatch_async(self.callbackQueue, ^{
                    if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestSucceed:didReceiveResponse:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                               sendRequestSucceed:request
                                               didReceiveResponse:response];
                    }
                    [request.delegate onRequestSuccess:response];
                });
            }
        }
        
        if (response.ret != RET_SUCCESS) {
            if (![self shouldIgnoreResponseError:response])
            {
                if (response.error == nil)
                {
                    response.error = [BaseNetworkError errorWithHttpStatusCode:response.statusCode serverReturnValue:response.ret serverErrorCode:response.errcode serverErrorType:RESPONSE_PARSE_RET_ERROR serverErrorMsg:response.msg];
                }
                else
                {
                    response.error.serverErrorType = RESPONSE_PARSE_RET_ERROR;
                }
            }
            
            if (response.ret == RESPONSE_DATA_INVALID) {
                
                dispatch_async(self.callbackQueue, ^{
                    if ([self.eventsDelegate respondsToSelector:@selector(communicationManager:didReceiveInvalidDataResponse:)]) {
                        [self.eventsDelegate communicationManager:(id)self
                                    didReceiveInvalidDataResponse:response];
                    }
                });
            }
            
            dispatch_async(self.callbackQueue, ^{
                if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                    [self.eventsDelegate communicationManager:(id)self
                                            sendRequestFailed:request
                                                     response:response];
                }
                [request.delegate onRequestFail:response];
            });
        }
        
  
    });
}






- (void)onRequestFail:(LSBaseRequest *)request responseStatusCode:(NSInteger)statuscode withError:(NSError *)error
{
    dispatch_async(self.isolationQueue, ^{
        //返回错误
        
        //ADD BY WenZhneg Zhang
        LSBaseResponse* response = [self responseFromRequest:request ResponseData:nil];
        [self setUpErrorMessageToResponse:response responseStatusCode:statuscode withError:error];
        
        if(request.delegate) {
            dispatch_async(self.callbackQueue, ^{
                if (self.eventsDelegate && [self.eventsDelegate respondsToSelector:@selector(communicationManager:sendRequestFailed:response:)]) {
                    [self.eventsDelegate communicationManager:(id)self
                                            sendRequestFailed:request
                                                     response:response];
                }
                [request.delegate onRequestFail:response];
            });
        }

    });
}

- (void)setUpErrorMessageToResponse:(LSBaseResponse *)response
                 responseStatusCode:(NSInteger)statuscode
                          withError:(NSError *)error {
    response.ret = RET_DEFAULT_ERROR;
    
    if (statuscode == kHttpStatusCodeRequstErrorRequestTimeout || statuscode == kHttpStatusCodeServerErrorGatewayTimeout || (error && [error code] == -1001)) {
        NSString *netTimeOutStr = @"网络链接超时";
        response.error = [BaseNetworkError errorWithHttpStatusCode:statuscode serverReturnValue:RET_DEFAULT_ERROR serverErrorCode:0 serverErrorType:REQUEST_TIMEOUT serverErrorMsg:netTimeOutStr];
        response.msg = netTimeOutStr;
    }
    else if (statuscode == kHttpStatusCodeRequstErrorNotFound || statuscode == kHttpStatusCodeRequstErrorForbidden || statuscode == kHttpStatusCodeServerErrorBadGateway) {
        NSString *netExceptionStr = @"网络异常,请稍后再试";
        response.error = [BaseNetworkError errorWithHttpStatusCode:statuscode serverReturnValue:RET_DEFAULT_ERROR serverErrorCode:0 serverErrorType:REQUEST_CONNECTION_FAILED serverErrorMsg: netExceptionStr];
        response.msg = netExceptionStr;
    }
    else {
        NSString *netExcpStr = @"网络异常,请稍后再试";
        response.error = [BaseNetworkError errorWithHttpStatusCode:statuscode serverReturnValue:RET_DEFAULT_ERROR serverErrorCode:0 serverErrorType:COMMON_NETWORK_ERROR serverErrorMsg:netExcpStr];
        response.msg = netExcpStr;
    }
    
    //        if (error) {
    //            response.error.nativeError = error;
    //        }
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey:response.msg};
    NSError *nError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
    response.nsError = nError;
    response.statusCode = statuscode;
}

- (BOOL)shouldIgnoreResponseError:(LSBaseResponse*)response {
    if (response.ret == RET_NO_NEW_SOFTWARE_VERSION) {
        return YES;
    }
    return NO;
}

@end
