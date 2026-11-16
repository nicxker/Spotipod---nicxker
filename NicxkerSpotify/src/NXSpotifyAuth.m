// NXSpotifyAuth.m — OAuth2 · avoids apresolve entirely, uses Web API only
#import "NXSpotifyAuth.h"
#import "NXHTTPClient.h"

#define NX_CLIENT_SECRET @"YOUR_SPOTIFY_CLIENT_SECRET"
#define NX_TOKEN_URL     @"https://accounts.spotify.com/api/token"
#define NX_AUTH_URL      @"https://accounts.spotify.com/authorize"
#define NX_STATE         @"nicxker_state_v1"

static NXSpotifyAuth *_instance;

@implementation NXSpotifyAuth

+ (instancetype)shared {
    static dispatch_once_t t;
    dispatch_once(&t, ^{ _instance = [[self alloc] init]; });
    return _instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        self.accessToken  = [d stringForKey:@"nx_access_token"];
        self.refreshToken = [d stringForKey:@"nx_refresh_token"];
        self.tokenExpiry  = [d objectForKey:@"nx_token_expiry"];
    }
    return self;
}

- (BOOL)isLoggedIn {
    return self.refreshToken.length > 0;
}

- (BOOL)isTokenValid {
    return self.accessToken.length > 0 &&
           self.tokenExpiry &&
           [self.tokenExpiry timeIntervalSinceNow] > 60;
}

- (NSURL *)authorizationURL {
    NSString *s = [NSString stringWithFormat:
        @"%@?client_id=%@&response_type=code&redirect_uri=%@&scope=%@&state=%@&show_dialog=false",
        NX_AUTH_URL,
        NX_CLIENT_ID,
        [NX_REDIRECT_URI stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [NX_SCOPES stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        NX_STATE
    ];
    return [NSURL URLWithString:s];
}

- (BOOL)handleCallbackURL:(NSURL *)url {
    if (![url.scheme isEqualToString:@"nicxker"]) return NO;

    NSString *query = url.query;
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if (kv.count == 2) params[kv[0]] = [kv[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }

    NSString *code  = params[@"code"];
    NSString *state = params[@"state"];
    if (!code || ![state isEqualToString:NX_STATE]) return NO;

    [self exchangeCode:code];
    return YES;
}

- (void)exchangeCode:(NSString *)code {
    NSString *body = [NSString stringWithFormat:
        @"grant_type=authorization_code&code=%@&redirect_uri=%@",
        code,
        [NX_REDIRECT_URI stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    [self postToken:body completion:^(BOOL ok) {
        if (ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NXLoginSuccess" object:nil];
            });
        }
    }];
}

- (void)refreshAccessToken:(void(^)(BOOL))completion {
    if ([self isTokenValid]) { if (completion) completion(YES); return; }
    NSString *body = [NSString stringWithFormat:
        @"grant_type=refresh_token&refresh_token=%@", self.refreshToken];
    [self postToken:body completion:completion];
}

- (void)postToken:(NSString *)body completion:(void(^)(BOOL))completion {
    // Build Basic Auth header
    NSString *creds = [NSString stringWithFormat:@"%@:%@", NX_CLIENT_ID, NX_CLIENT_SECRET];
    NSData *credsData = [creds dataUsingEncoding:NSUTF8StringEncoding];
    NSString *b64 = [credsData base64Encoding]; // iOS 6 method
    NSString *auth = [@"Basic " stringByAppendingString:b64];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:NX_TOKEN_URL]];
    req.HTTPMethod = @"POST";
    [req setValue:auth forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    req.timeoutInterval = 15;

    [[NXHTTPClient shared] sendRequest:req completion:^(NSData *data, NSError *err) {
        if (!data) { if (completion) completion(NO); return; }
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!j[@"access_token"]) { if (completion) completion(NO); return; }

        self.accessToken = j[@"access_token"];
        if (j[@"refresh_token"]) self.refreshToken = j[@"refresh_token"];
        self.tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:[j[@"expires_in"] doubleValue]];

        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:self.accessToken  forKey:@"nx_access_token"];
        [d setObject:self.refreshToken forKey:@"nx_refresh_token"];
        [d setObject:self.tokenExpiry  forKey:@"nx_token_expiry"];
        [d synchronize];

        if (completion) completion(YES);
    }];
}

- (void)logout {
    self.accessToken = self.refreshToken = nil;
    self.tokenExpiry = nil;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:@"nx_access_token"];
    [d removeObjectForKey:@"nx_refresh_token"];
    [d removeObjectForKey:@"nx_token_expiry"];
    [d synchronize];
}

@end

