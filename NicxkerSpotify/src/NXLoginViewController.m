// NXLoginViewController.m — Clean login screen with Spotify OAuth via UIWebView
#import <UIKit/UIKit.h>
#import "NXSpotifyAuth.h"

#import "NXLoginViewController.h"

@implementation NXLoginViewController {
    UILabel      *_titleLabel;
    UILabel      *_subtitleLabel;
    UIButton     *_loginButton;
    UIView       *_loadingView;
    UIWebView    *_webView;
    UIActivityIndicatorView *_spinner;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1];

    // ── Gradient background ──────────────────────────────────────────────────
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame  = self.view.bounds;
    grad.colors = @[
        (id)[UIColor colorWithRed:0.0 green:0.4 blue:0.25 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1].CGColor
    ];
    grad.locations = @[@0.0, @0.6];
    [self.view.layer insertSublayer:grad atIndex:0];

    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;

    // ── Spotify-green circle icon ────────────────────────────────────────────
    UIView *circle = [[UIView alloc] initWithFrame:CGRectMake((W - 80)/2, H * 0.18, 80, 80)];
    circle.layer.cornerRadius = 40;
    circle.backgroundColor = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1];
    [self.view addSubview:circle];

    UILabel *note = [[UILabel alloc] initWithFrame:circle.bounds];
    note.text = @"♫";
    note.textAlignment = NSTextAlignmentCenter;
    note.font = [UIFont systemFontOfSize:40];
    [circle addSubview:note];

    // ── Title ────────────────────────────────────────────────────────────────
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, H * 0.38, W - 40, 40)];
    _titleLabel.text = @"nicxker";
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.font = [UIFont boldSystemFontOfSize:34];
    _titleLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, H * 0.38 + 46, W - 40, 24)];
    _subtitleLabel.text = @"Spotify for your iPod";
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.font = [UIFont systemFontOfSize:16];
    _subtitleLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    [self.view addSubview:_subtitleLabel];

    // ── Login button ─────────────────────────────────────────────────────────
    _loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _loginButton.frame = CGRectMake(32, H - 150, W - 64, 46);
    _loginButton.backgroundColor = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1];
    _loginButton.layer.cornerRadius = 23;
    [_loginButton setTitle:@"Log in with Spotify" forState:UIControlStateNormal];
    [_loginButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_loginButton addTarget:self action:@selector(loginTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_loginButton];

    // ── Manual Token Button ──────────────────────────────────────────────────
    UIButton *tokenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    tokenBtn.frame = CGRectMake(32, H - 94, W - 64, 38);
    tokenBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    tokenBtn.layer.cornerRadius = 19;
    [tokenBtn setTitle:@"Enter Token Manually" forState:UIControlStateNormal];
    [tokenBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tokenBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [tokenBtn addTarget:self action:@selector(manualTokenTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:tokenBtn];

    // ── Version label ────────────────────────────────────────────────────────
    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(0, H - 30, W, 20)];
    ver.text = @"by nicxker · v1.0";
    ver.textAlignment = NSTextAlignmentCenter;
    ver.font = [UIFont systemFontOfSize:11];
    ver.textColor = [UIColor colorWithWhite:0.3 alpha:1];
    [self.view addSubview:ver];

    // ── WebView (hidden, used for OAuth) ─────────────────────────────────────
    _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 44, W, H - 44)];
    _webView.delegate = self;
    _webView.hidden = YES;
    [self.view addSubview:_webView];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(loginSuccess) name:@"NXLoginSuccess" object:nil];
}

- (void)loginTapped {
    _webView.hidden = NO;
    _loginButton.hidden = YES;
    NSURLRequest *req = [NSURLRequest requestWithURL:[[NXSpotifyAuth shared] authorizationURL]];
    [_webView loadRequest:req];
}

- (void)manualTokenTapped {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Spotify Token"
                                                    message:@"Paste your Spotify OAuth Access Token below:"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save & Connect", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *tf = [alert textFieldAtIndex:0];
    tf.placeholder = @"OAuth Token...";
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *tok = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (tok.length > 0) {
            [NXSpotifyAuth shared].accessToken = tok;
            [NXSpotifyAuth shared].refreshToken = tok;
            [NXSpotifyAuth shared].tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:86400 * 365];
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            [d setObject:tok forKey:@"nx_access_token"];
            [d setObject:tok forKey:@"nx_refresh_token"];
            [d setObject:[NSDate dateWithTimeIntervalSinceNow:86400 * 365] forKey:@"nx_token_expiry"];
            [d synchronize];
            [self loginSuccess];
        }
    }
}

- (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)req navigationType:(UIWebViewNavigationType)t {
    if ([req.URL.scheme isEqualToString:@"nicxker"]) {
        [[NXSpotifyAuth shared] handleCallbackURL:req.URL];
        return NO;
    }
    return YES;
}

- (void)loginSuccess {
    // Transition to main tab bar
    UIViewController *main = [[NXMainTabController alloc] init];
    UIWindow *win = [UIApplication sharedApplication].keyWindow;
    // Smooth cross-dissolve transition
    [UIView transitionWithView:win duration:0.4
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{ win.rootViewController = main; }
                    completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

