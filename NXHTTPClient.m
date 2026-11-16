// NXHTTPClient.m — async HTTP via NSURLConnection with SSL bypass for iOS 6
#import "NXHTTPClient.h"
#import "NXSpotifyAuth.h"

// Bypass SSL certificate expiration / untrusted root CA on iOS 6
@interface NSURLRequest (NXSSL)
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host;
@end

@implementation NSURLRequest (NXSSL)
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host {
    return YES;
}
@end

@implementation NXHTTPClient

+ (instancetype)shared {
    static NXHTTPClient *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[self alloc] init]; });
    return i;
}

- (void)sendRequest:(NSURLRequest *)req completion:(NXHTTPCompletion)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *err = nil;
        NSURLResponse *resp = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(data, err);
        });
    });
}

- (void)GET:(NSString *)urlStr completion:(NXHTTPCompletion)completion {
    NXSpotifyAuth *auth = [NXSpotifyAuth shared];
    if (!auth.accessToken.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"NX" code:401 userInfo:nil]);
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"GET";
    [req setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
    req.timeoutInterval = 10;
    [self sendRequest:req completion:completion];
}

- (void)PUT:(NSString *)urlStr body:(NSData *)body completion:(NXHTTPCompletion)completion {
    NXSpotifyAuth *auth = [NXSpotifyAuth shared];
    if (!auth.accessToken.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"NX" code:401 userInfo:nil]);
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"PUT";
    [req setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = body;
    req.timeoutInterval = 10;
    [self sendRequest:req completion:completion];
}

- (void)POST:(NSString *)urlStr body:(NSData *)body completion:(NXHTTPCompletion)completion {
    NXSpotifyAuth *auth = [NXSpotifyAuth shared];
    if (!auth.accessToken.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"NX" code:401 userInfo:nil]);
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = body;
    req.timeoutInterval = 10;
    [self sendRequest:req completion:completion];
}

@end
