// NXHTTPClient.m — async HTTP via NSURLConnection (no AFNetworking, stays lightweight)
#import "NXHTTPClient.h"
#import "NXSpotifyAuth.h"

#define NX_API_BASE @"https://api.spotify.com/v1"

@implementation NXHTTPClient

+ (instancetype)shared {
    static NXHTTPClient *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[self alloc] init]; });
    return i;
}

// Core: attach auth header then fire off on a background queue
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

// Convenience: GET with Spotify Bearer token (auto-refresh if needed)
- (void)GET:(NSString *)urlStr completion:(NXHTTPCompletion)completion {
    NXSpotifyAuth *auth = [NXSpotifyAuth shared];
    [auth refreshAccessToken:^(BOOL ok) {
        if (!ok) { if (completion) completion(nil, nil); return; }
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"GET";
        [req setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
        req.timeoutInterval = 15;
        [self sendRequest:req completion:completion];
    }];
}

- (void)PUT:(NSString *)urlStr body:(NSData *)body completion:(NXHTTPCompletion)completion {
    NXSpotifyAuth *auth = [NXSpotifyAuth shared];
    [auth refreshAccessToken:^(BOOL ok) {
        if (!ok) { if (completion) completion(nil, nil); return; }
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"PUT";
        [req setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        req.HTTPBody = body;
        req.timeoutInterval = 15;
        [self sendRequest:req completion:completion];
    }];
}

- (void)POST:(NSString *)urlStr body:(NSData *)body completion:(NXHTTPCompletion)completion {
    NXSpotifyAuth *auth = [NXSpotifyAuth shared];
    [auth refreshAccessToken:^(BOOL ok) {
        if (!ok) { if (completion) completion(nil, nil); return; }
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"POST";
        [req setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        req.HTTPBody = body;
        req.timeoutInterval = 15;
        [self sendRequest:req completion:completion];
    }];
}

@end

