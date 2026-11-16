// NXSpotifyAuth.h — OAuth2 + token management
#import <Foundation/Foundation.h>

#define NX_CLIENT_ID     @"YOUR_SPOTIFY_CLIENT_ID"
#define NX_REDIRECT_URI  @"nicxker://callback"
#define NX_SCOPES        @"user-read-playback-state user-modify-playback-state user-read-currently-playing streaming user-library-read user-library-modify playlist-read-private"

@interface NXSpotifyAuth : NSObject

@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy) NSString *refreshToken;
@property (nonatomic, strong) NSDate *tokenExpiry;

+ (instancetype)shared;
- (BOOL)isLoggedIn;
- (NSURL *)authorizationURL;
- (BOOL)handleCallbackURL:(NSURL *)url;
- (void)refreshAccessToken:(void(^)(BOOL success))completion;
- (void)logout;

@end

