// NXPlayerViewController.m — Pixel-perfect Now Playing for iPod Touch 4 (320x480)
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "NXSpotifyAPI.h"

#define NX_GREEN [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1]
#define NX_BG    [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1]
#define NX_GRAY  [UIColor colorWithWhite:0.5 alpha:1]

#import "NXPlayerViewController.h"

@implementation NXPlayerViewController {
    UIImageView  *_artView;
    UIView       *_artShadow;
    UILabel      *_trackLabel;
    UILabel      *_artistLabel;
    UIButton     *_heartButton;
    UISlider     *_seekSlider;
    UILabel      *_progressLabel;
    UILabel      *_durationLabel;
    UIButton     *_prevButton;
    UIButton     *_playPauseButton;
    UIButton     *_nextButton;
    UISlider     *_volumeSlider;
    UILabel      *_deviceLabel;

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
    [_pollTimer invalidate];
    _pollTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self
                  selector:@selector(fetchState) userInfo:nil repeats:YES];
    [_progressTimer invalidate];
    _progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                      selector:@selector(tickProgress) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_pollTimer invalidate]; _pollTimer = nil;
    [_progressTimer invalidate]; _progressTimer = nil;
}

// ── Build UI specifically sized for 3.5" iPod touch screen (320 x 480) ────────
- (void)buildUI {
    CGFloat W = self.view.bounds.size.width; // 320

    // 1. Album Art (165 x 165) centered
    CGFloat artSize = 165;
    CGFloat artX = (W - artSize) / 2; // 77.5
    _artShadow = [[UIView alloc] initWithFrame:CGRectMake(artX, 14, artSize, artSize)];
    _artShadow.layer.shadowColor   = [UIColor blackColor].CGColor;
    _artShadow.layer.shadowOffset  = CGSizeMake(0, 4);
    _artShadow.layer.shadowOpacity = 0.7;
    _artShadow.layer.shadowRadius  = 8;
    [self.view addSubview:_artShadow];

    _artView = [[UIImageView alloc] initWithFrame:_artShadow.bounds];
    _artView.backgroundColor    = [UIColor colorWithWhite:0.15 alpha:1];
    _artView.layer.cornerRadius = 8;
    _artView.clipsToBounds      = YES;
    _artView.contentMode        = UIViewContentModeScaleAspectFill;
    [_artShadow addSubview:_artView];

    // Heart button (top right)
    _heartButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _heartButton.frame = CGRectMake(W - 46, 14, 36, 36);
    [_heartButton setTitle:@"♡" forState:UIControlStateNormal];
    [_heartButton setTitle:@"♥" forState:UIControlStateSelected];
    [_heartButton setTitleColor:NX_GRAY forState:UIControlStateNormal];
    [_heartButton setTitleColor:NX_GREEN forState:UIControlStateSelected];
    _heartButton.titleLabel.font = [UIFont systemFontOfSize:22];
    [_heartButton addTarget:self action:@selector(heartTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_heartButton];

    // 2. Track & Artist Labels (centered)
    _trackLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 188, W - 32, 22)];
    _trackLabel.textColor     = [UIColor whiteColor];
    _trackLabel.font          = [UIFont boldSystemFontOfSize:16];
    _trackLabel.textAlignment = NSTextAlignmentCenter;
    _trackLabel.text          = @"Not Playing";
    [self.view addSubview:_trackLabel];

    _artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 210, W - 32, 18)];
    _artistLabel.textColor     = NX_GRAY;
    _artistLabel.font          = [UIFont systemFontOfSize:13];
    _artistLabel.textAlignment = NSTextAlignmentCenter;
    _artistLabel.text          = @"Play music on PC / Phone";
    [self.view addSubview:_artistLabel];

    // 3. Seek Bar & Time Labels
    _seekSlider = [[UISlider alloc] initWithFrame:CGRectMake(24, 232, W - 48, 18)];
    _seekSlider.minimumTrackTintColor = NX_GREEN;
    _seekSlider.maximumTrackTintColor = [UIColor colorWithWhite:0.25 alpha:1];
    _seekSlider.thumbTintColor        = [UIColor whiteColor];
    [_seekSlider addTarget:self action:@selector(seekBegan) forControlEvents:UIControlEventTouchDown];
    [_seekSlider addTarget:self action:@selector(seekEnded) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    [self.view addSubview:_seekSlider];

    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 250, 60, 14)];
    _progressLabel.textColor = NX_GRAY;
    _progressLabel.font      = [UIFont systemFontOfSize:10];
    _progressLabel.text      = @"0:00";
    [self.view addSubview:_progressLabel];

    _durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(W - 84, 250, 60, 14)];
    _durationLabel.textColor     = NX_GRAY;
    _durationLabel.font          = [UIFont systemFontOfSize:10];
    _durationLabel.textAlignment = NSTextAlignmentRight;
    _durationLabel.text          = @"0:00";
    [self.view addSubview:_durationLabel];

    // 4. Playback Controls (Previous, Play/Pause, Next)
    _prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _prevButton.frame = CGRectMake(W/2 - 82, 272, 44, 44);
    [_prevButton setTitle:@"⏮" forState:UIControlStateNormal];
    [_prevButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _prevButton.titleLabel.font = [UIFont systemFontOfSize:22];
    [_prevButton addTarget:self action:@selector(prevTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_prevButton];

    _playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _playPauseButton.frame = CGRectMake(W/2 - 27, 267, 54, 54);
    _playPauseButton.backgroundColor    = NX_GREEN;
    _playPauseButton.layer.cornerRadius = 27;
    [_playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
    [_playPauseButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _playPauseButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [_playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playPauseButton];

    _nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _nextButton.frame = CGRectMake(W/2 + 38, 272, 44, 44);
    [_nextButton setTitle:@"⏭" forState:UIControlStateNormal];
    [_nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _nextButton.titleLabel.font = [UIFont systemFontOfSize:22];
    [_nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_nextButton];

    // 5. Volume Slider
    UILabel *volMin = [[UILabel alloc] initWithFrame:CGRectMake(24, 332, 16, 16)];
    volMin.text = @"🔈"; volMin.font = [UIFont systemFontOfSize:11];
    [self.view addSubview:volMin];

    _volumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(44, 332, W - 88, 16)];
    _volumeSlider.minimumTrackTintColor = NX_GREEN;
    _volumeSlider.maximumTrackTintColor = [UIColor colorWithWhite:0.25 alpha:1];
    _volumeSlider.value = 1.0;
    [_volumeSlider addTarget:self action:@selector(volumeChanged) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    [self.view addSubview:_volumeSlider];

    UILabel *volMax = [[UILabel alloc] initWithFrame:CGRectMake(W - 40, 332, 16, 16)];
    volMax.text = @"🔊"; volMax.font = [UIFont systemFontOfSize:11];
    [self.view addSubview:volMax];

    // 6. Device indicator label
    _deviceLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 360, W - 32, 16)];
    _deviceLabel.textColor     = NX_GREEN;
    _deviceLabel.font          = [UIFont systemFontOfSize:11];
    _deviceLabel.textAlignment = NSTextAlignmentCenter;
    _deviceLabel.text          = @"🟢 nicxker · Spotify Connect";
    [self.view addSubview:_deviceLabel];
}

- (void)fetchState {
    [[NXSpotifyAPI shared] currentPlaybackState:^(NXPlaybackState *s, NSError *e) {
        if (!s) {
            if (!_state) {
                _trackLabel.text  = @"Not Playing";
                _artistLabel.text = @"Play music on PC / Phone";
                [_playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
            }
            return;
        }
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
    if (t) {
        _trackLabel.text  = t.name ?: @"Unknown Track";
        _artistLabel.text = t.artist ?: @"";
    }
    [_playPauseButton setTitle:_state.isPlaying ? @"⏸" : @"▶" forState:UIControlStateNormal];
    _volumeSlider.value = _state.volumePercent / 100.0f;

    [self updateSeekBar];

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
                    if (_imageCache.count > 20) [_imageCache removeAllObjects];
                    _imageCache[url] = img;
                    dispatch_async(dispatch_get_main_queue(), ^{ _artView.image = img; });
                }
            });
        }
    }
}

- (void)updateSeekBar {
    if (_isSeeking || !_state.track) return;
    NSInteger dur = _state.track.durationMs;
    NSInteger cur = _state.progressMs;
    if (dur > 0) {
        _seekSlider.value = (float)cur / (float)dur;
        _progressLabel.text = [self formatMs:cur];
        _durationLabel.text = [self formatMs:dur];
    }
}

- (NSString *)formatMs:(NSInteger)ms {
    NSInteger s = ms / 1000;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(s / 60), (long)(s % 60)];
}

- (void)playPauseTapped {
    if (_state.isPlaying) {
        [[NXSpotifyAPI shared] pause:^(BOOL ok) {
            _state.isPlaying = NO;
            [_playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
        }];
    } else {
        [[NXSpotifyAPI shared] play:nil deviceID:nil completion:^(BOOL ok) {
            _state.isPlaying = YES;
            [_playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
        }];
    }
}

- (void)prevTapped {
    [[NXSpotifyAPI shared] previous:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self fetchState];
    });
}

- (void)nextTapped {
    [[NXSpotifyAPI shared] next:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self fetchState];
    });
}

- (void)seekBegan { _isSeeking = YES; }

- (void)seekEnded {
    _isSeeking = NO;
    if (!_state.track) return;
    NSInteger targetMs = (NSInteger)(_seekSlider.value * _state.track.durationMs);
    _state.progressMs = targetMs;
    [[NXSpotifyAPI shared] seekTo:targetMs completion:nil];
}

- (void)volumeChanged {
    NSInteger pct = (NSInteger)(_volumeSlider.value * 100);
    [[NXSpotifyAPI shared] setVolume:pct completion:nil];
}

- (void)heartTapped {
    if (!_state.track) return;
    _heartButton.selected = !_heartButton.selected;
    if (_heartButton.selected) {
        [[NXSpotifyAPI shared] saveTrack:_state.track.trackID completion:nil];
    } else {
        [[NXSpotifyAPI shared] unsaveTrack:_state.track.trackID completion:nil];
    }
}

@end
