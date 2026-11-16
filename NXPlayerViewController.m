// NXPlayerViewController.m — Now Playing screen with album art, controls, seek bar
// Optimized: polling instead of websockets (iOS 6 compat), image caching, no CoreAnimation overdraw

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "NXSpotifyAPI.h"

#define NX_GREEN [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1]
#define NX_BG    [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1]
#define NX_GRAY  [UIColor colorWithWhite:0.4 alpha:1]

#import "NXPlayerViewController.h"

@implementation NXPlayerViewController {
    // Album art
    UIImageView  *_artView;
    UIView       *_artShadow;
    
    // Track info
    UILabel      *_trackLabel;
    UILabel      *_artistLabel;
    UIButton     *_heartButton;
    
    // Seek bar
    UISlider     *_seekSlider;
    UILabel      *_progressLabel;
    UILabel      *_durationLabel;
    
    // Controls
    UIButton     *_prevButton;
    UIButton     *_playPauseButton;
    UIButton     *_nextButton;
    UISlider     *_volumeSlider;
    
    // State
    NXPlaybackState *_state;
    NSTimer      *_pollTimer;
    NSTimer      *_progressTimer;
    BOOL          _isSeeking;
    NSMutableDictionary *_imageCache;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = NX_BG;
    _imageCache = [NSMutableDictionary dictionary];
    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self fetchState];
    // Poll every 3s — lightweight, no websockets needed
    _pollTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self
                  selector:@selector(fetchState) userInfo:nil repeats:YES];
    // Update progress bar every second locally (no network)
    _progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                      selector:@selector(tickProgress) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_pollTimer invalidate]; _pollTimer = nil;
    [_progressTimer invalidate]; _progressTimer = nil;
}

// ── Build UI ──────────────────────────────────────────────────────────────────
- (void)buildUI {
    CGFloat W = self.view.bounds.size.width;   // 320 on iPod 4
    CGFloat H = self.view.bounds.size.height;  // 480
    CGFloat artSize = W - 48;

    // Art shadow
    _artShadow = [[UIView alloc] initWithFrame:CGRectMake(24, 32, artSize, artSize)];
    _artShadow.layer.shadowColor   = [UIColor blackColor].CGColor;
    _artShadow.layer.shadowOffset  = CGSizeMake(0, 8);
    _artShadow.layer.shadowOpacity = 0.6;
    _artShadow.layer.shadowRadius  = 12;
    [self.view addSubview:_artShadow];

    // Album art
    _artView = [[UIImageView alloc] initWithFrame:_artShadow.bounds];
    _artView.backgroundColor   = [UIColor colorWithWhite:0.15 alpha:1];
    _artView.layer.cornerRadius = 6;
    _artView.clipsToBounds     = YES;
    _artView.contentMode       = UIViewContentModeScaleAspectFill;
    [_artShadow addSubview:_artView];

    CGFloat y = 32 + artSize + 20;

    // Track name
    _trackLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, W - 60, 24)];
    _trackLabel.textColor = [UIColor whiteColor];
    _trackLabel.font      = [UIFont boldSystemFontOfSize:18];
    _trackLabel.text      = @"Not playing";
    [self.view addSubview:_trackLabel];

    // Heart button
    _heartButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _heartButton.frame = CGRectMake(W - 48, y, 36, 36);
    [_heartButton setTitle:@"♡" forState:UIControlStateNormal];
    [_heartButton setTitle:@"♥" forState:UIControlStateSelected];
    [_heartButton setTitleColor:NX_GRAY forState:UIControlStateNormal];
    [_heartButton setTitleColor:NX_GREEN forState:UIControlStateSelected];
    _heartButton.titleLabel.font = [UIFont systemFontOfSize:24];
    [_heartButton addTarget:self action:@selector(heartTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_heartButton];

    // Artist name
    _artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 26, W - 32, 20)];
    _artistLabel.textColor = NX_GRAY;
    _artistLabel.font      = [UIFont systemFontOfSize:14];
    [self.view addSubview:_artistLabel];

    y += 56;

    // Seek slider
    _seekSlider = [[UISlider alloc] initWithFrame:CGRectMake(16, y, W - 32, 20)];
    _seekSlider.minimumTrackTintColor = NX_GREEN;
    _seekSlider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1];
    _seekSlider.thumbTintColor        = [UIColor whiteColor];
    [_seekSlider addTarget:self action:@selector(seekBegan) forControlEvents:UIControlEventTouchDown];
    [_seekSlider addTarget:self action:@selector(seekEnded) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    [self.view addSubview:_seekSlider];

    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 22, 60, 16)];
    _progressLabel.textColor = NX_GRAY;
    _progressLabel.font      = [UIFont systemFontOfSize:11];
    _progressLabel.text      = @"0:00";
    [self.view addSubview:_progressLabel];

    _durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(W - 60, y + 22, 44, 16)];
    _durationLabel.textColor    = NX_GRAY;
    _durationLabel.font         = [UIFont systemFontOfSize:11];
    _durationLabel.textAlignment = NSTextAlignmentRight;
    _durationLabel.text         = @"0:00";
    [self.view addSubview:_durationLabel];

    y += 46;

    // ── Controls ─────────────────────────────────────────────────────────────
    CGFloat btnY = y + 4;
    _prevButton = [self controlButton:@"⏮" frame:CGRectMake(W/2 - 100, btnY, 44, 44)];
    [_prevButton addTarget:self action:@selector(prevTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_prevButton];

    _playPauseButton = [self controlButton:@"▶" frame:CGRectMake(W/2 - 28, btnY - 6, 56, 56)];
    _playPauseButton.backgroundColor   = NX_GREEN;
    _playPauseButton.layer.cornerRadius = 28;
    [_playPauseButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _playPauseButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [_playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playPauseButton];

    _nextButton = [self controlButton:@"⏭" frame:CGRectMake(W/2 + 56, btnY, 44, 44)];
    [_nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_nextButton];

    // Volume slider
    UILabel *volIcon = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 60, 20, 20)];
    volIcon.text = @"🔈"; volIcon.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:volIcon];

    _volumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(38, y + 62, W - 70, 16)];
    _volumeSlider.minimumTrackTintColor = NX_GREEN;
    _volumeSlider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1];
    _volumeSlider.value = 1.0;
    [_volumeSlider addTarget:self action:@selector(volumeChanged) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    [self.view addSubview:_volumeSlider];

    UILabel *volMaxIcon = [[UILabel alloc] initWithFrame:CGRectMake(W - 28, y + 60, 20, 20)];
    volMaxIcon.text = @"🔊"; volMaxIcon.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:volMaxIcon];
}

- (UIButton *)controlButton:(NSString *)title frame:(CGRect)f {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = f;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b setTitleColor:NX_GREEN forState:UIControlStateHighlighted];
    b.titleLabel.font = [UIFont systemFontOfSize:22];
    return b;
}

// ── State polling ─────────────────────────────────────────────────────────────
- (void)fetchState {
    [[NXSpotifyAPI shared] currentPlaybackState:^(NXPlaybackState *s, NSError *e) {
        if (!s) return;
        _state = s;
        [self updateUI];
    }];
}

- (void)tickProgress {
    if (!_state || !_state.isPlaying || _isSeeking) return;
    _state.progressMs += 1000;
    if (_state.track && _state.progressMs > _state.track.durationMs) return;
    [self updateSeekBar];
}

- (void)updateUI {
    NXTrack *t = _state.track;
    _trackLabel.text  = t.name ?: @"Not playing";
    _artistLabel.text = t.artist;
    [_playPauseButton setTitle:_state.isPlaying ? @"⏸" : @"▶" forState:UIControlStateNormal];
    _volumeSlider.value = _state.volumePercent / 100.0f;

    [self updateSeekBar];

    // Album art — cache by URL to avoid redundant downloads
    NSString *url = t.imageURL;
    if (url) {
        UIImage *cached = _imageCache[url];
        if (cached) {
            _artView.image = cached;
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
                UIImage *img = [UIImage imageWithData:data];
                if (img) {
                    // keep cache small — 20 entries max
                    if (_imageCache.count > 20) [_imageCache removeAllObjects];
                    _imageCache[url] = img;
                    dispatch_async(dispatch_get_main_queue(), ^{ _artView.image = img; });
                }
            });
        }
    } else {
        _artView.image = nil;
    }

    // Heart
    if (t.trackID) {
        [[NXSpotifyAPI shared] isTrackSaved:t.trackID completion:^(BOOL saved) {
            _heartButton.selected = saved;
        }];
    }
}

- (void)updateSeekBar {
    if (!_state.track) return;
    CGFloat dur = _state.track.durationMs;
    if (dur <= 0) return;
    _seekSlider.value     = _state.progressMs / dur;
    _progressLabel.text   = [self formatMs:_state.progressMs];
    _durationLabel.text   = [self formatMs:_state.track.durationMs];
}

- (NSString *)formatMs:(NSInteger)ms {
    NSInteger s = ms / 1000;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(s/60), (long)(s%60)];
}

// ── Controls ──────────────────────────────────────────────────────────────────
- (void)playPauseTapped {
    if (_state.isPlaying) {
        [[NXSpotifyAPI shared] pause:nil];
        _state.isPlaying = NO;
    } else {
        [[NXSpotifyAPI shared] play:nil deviceID:_state.deviceID completion:nil];
        _state.isPlaying = YES;
    }
    [_playPauseButton setTitle:_state.isPlaying ? @"⏸" : @"▶" forState:UIControlStateNormal];
}

- (void)prevTapped { [[NXSpotifyAPI shared] previous:nil]; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self fetchState]; }); }
- (void)nextTapped { [[NXSpotifyAPI shared] next:nil];     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self fetchState]; }); }

- (void)seekBegan { _isSeeking = YES; }
- (void)seekEnded {
    _isSeeking = NO;
    if (!_state.track) return;
    NSInteger ms = (NSInteger)(_seekSlider.value * _state.track.durationMs);
    _state.progressMs = ms;
    [[NXSpotifyAPI shared] seekTo:ms completion:nil];
}

- (void)volumeChanged {
    NSInteger pct = (NSInteger)(_volumeSlider.value * 100);
    [[NXSpotifyAPI shared] setVolume:pct completion:nil];
}

- (void)heartTapped {
    if (!_state.track.trackID) return;
    _heartButton.selected = !_heartButton.selected;
    if (_heartButton.selected) {
        [[NXSpotifyAPI shared] saveTrack:_state.track.trackID completion:nil];
    } else {
        [[NXSpotifyAPI shared] unsaveTrack:_state.track.trackID completion:nil];
    }
}

@end

