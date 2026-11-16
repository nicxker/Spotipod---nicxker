// NXAppDelegate.m — Nicxker Spotify Client
// by nicxker · iOS 6 / iPod touch 4

#import "NXAppDelegate.h"
#import "NXSpotifyAuth.h"
#import "NXLoginViewController.h"
#import "NXMainTabController.h"

@implementation NXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];

    UIViewController *root;
    if ([[NXSpotifyAuth shared] isLoggedIn]) {
        root = [[NXMainTabController alloc] init];
    } else {
        root = [[NXLoginViewController alloc] init];
    }

    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    return YES;
}

// Spotify OAuth callback
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)src annotation:(id)ann {
    return [[NXSpotifyAuth shared] handleCallbackURL:url];
}

@end

