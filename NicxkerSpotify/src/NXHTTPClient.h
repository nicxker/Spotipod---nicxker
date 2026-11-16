// NXHTTPClient.h — Lightweight HTTP client using NSURLConnection (iOS 6 compatible)
#import <Foundation/Foundation.h>

typedef void(^NXHTTPCompletion)(NSData *data, NSError *error);

@interface NXHTTPClient : NSObject
+ (instancetype)shared;
- (void)sendRequest:(NSURLRequest *)req completion:(NXHTTPCompletion)completion;
- (void)GET:(NSString *)urlStr completion:(NXHTTPCompletion)completion;
- (void)PUT:(NSString *)urlStr body:(NSData *)body completion:(NXHTTPCompletion)completion;
- (void)POST:(NSString *)urlStr body:(NSData *)body completion:(NXHTTPCompletion)completion;
@end

