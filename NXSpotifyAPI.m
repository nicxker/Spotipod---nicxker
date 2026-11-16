// NXSpotifyAPI.m
#import "NXSpotifyAPI.h"
#import "NXHTTPClient.h"
#import "NXSpotifyAuth.h"

#define API @"https://api.spotify.com/v1"

// ─── NXTrack ────────────────────────────────────────────────────────────────
@implementation NXTrack
+ (instancetype)fromDict:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    NXTrack *t = [[NXTrack alloc] init];
    t.trackID    = d[@"id"];
    t.uri        = d[@"uri"];
    t.name       = d[@"name"];
    t.durationMs = [d[@"duration_ms"] integerValue];
    NSArray *artists = d[@"artists"];
    if (artists.count) {
        NSMutableArray *names = [NSMutableArray array];
        for (NSDictionary *a in artists) [names addObject:a[@"name"] ?: @""];
        t.artist = [names componentsJoinedByString:@", "];
    }
    NSDictionary *album = d[@"album"];
    if (album) {
        t.album = album[@"name"];
        NSArray *images = album[@"images"];
        // prefer the smallest image (last) to save bandwidth on old iPod
        if (images.count) t.imageURL = [images lastObject][@"url"];
    }
    return t;
}
@end

// ─── NXPlaybackState ─────────────────────────────────────────────────────────
@implementation NXPlaybackState
+ (instancetype)fromDict:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    NXPlaybackState *s = [[NXPlaybackState alloc] init];
    s.isPlaying  = [d[@"is_playing"] boolValue];
    s.progressMs = [d[@"progress_ms"] integerValue];
    s.track      = [NXTrack fromDict:d[@"item"]];
    NSDictionary *dev = d[@"device"];
    if (dev) {
        s.deviceID    = dev[@"id"];
        s.deviceName  = dev[@"name"];
        s.volumePercent = [dev[@"volume_percent"] integerValue];
    }
    return s;
}
@end

// ─── NXSpotifyAPI ────────────────────────────────────────────────────────────
@implementation NXSpotifyAPI

+ (instancetype)shared {
    static NXSpotifyAPI *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[self alloc] init]; });
    return i;
}

// ── Helpers ──────────────────────────────────────────────────────────────────
- (NSData *)json:(id)obj { return [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil]; }
- (NSDictionary *)parseData:(NSData *)data { return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil; }

- (NSArray *)tracksFromItems:(NSArray *)items {
    NSMutableArray *out = [NSMutableArray array];
    for (id item in items) {
        NSDictionary *dict = [item isKindOfClass:[NSDictionary class]] && item[@"track"] ? item[@"track"] : item;
        NXTrack *t = [NXTrack fromDict:dict];
        if (t) [out addObject:t];
    }
    return out;
}

// ── Search ───────────────────────────────────────────────────────────────────
- (void)searchTracks:(NSString *)query limit:(NSInteger)limit completion:(NXTracksCallback)cb {
    NSString *q = [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *url = [NSString stringWithFormat:@"%@/search?q=%@&type=track&limit=%ld", API, q, (long)limit];
    [[NXHTTPClient shared] GET:url completion:^(NSData *data, NSError *err) {
        if (err || !data) { if (cb) cb(nil, err); return; }
        NSDictionary *j = [self parseData:data];
        NSArray *items = j[@"tracks"][@"items"];
        if (cb) cb([self tracksFromItems:items], nil);
    }];
}

// ── Player ───────────────────────────────────────────────────────────────────
- (void)currentPlaybackState:(NXStateCallback)cb {
    [[NXHTTPClient shared] GET:[API stringByAppendingString:@"/me/player"] completion:^(NSData *data, NSError *err) {
        if (!data || data.length < 2) { if (cb) cb(nil, err); return; }
        NSDictionary *j = [self parseData:data];
        if (cb) cb([NXPlaybackState fromDict:j], nil);
    }];
}

- (void)play:(NSString *)spotifyURI deviceID:(NSString *)devID completion:(void(^)(BOOL))cb {
    NSString *url = [API stringByAppendingString:@"/me/player/play"];
    if (devID.length) url = [url stringByAppendingFormat:@"?device_id=%@", devID];
    NSDictionary *body = spotifyURI ? @{@"uris": @[spotifyURI]} : @{};
    [[NXHTTPClient shared] PUT:url body:[self json:body] completion:^(NSData *d, NSError *e) {
        if (cb) cb(e == nil);
    }];
}

- (void)pause:(void(^)(BOOL))cb {
    [[NXHTTPClient shared] PUT:[API stringByAppendingString:@"/me/player/pause"] body:nil completion:^(NSData *d, NSError *e) {
        if (cb) cb(e == nil);
    }];
}

- (void)next:(void(^)(BOOL))cb {
    [[NXHTTPClient shared] POST:[API stringByAppendingString:@"/me/player/next"] body:nil completion:^(NSData *d, NSError *e) {
        if (cb) cb(e == nil);
    }];
}

- (void)previous:(void(^)(BOOL))cb {
    [[NXHTTPClient shared] POST:[API stringByAppendingString:@"/me/player/previous"] body:nil completion:^(NSData *d, NSError *e) {
        if (cb) cb(e == nil);
    }];
}

- (void)seekTo:(NSInteger)ms completion:(void(^)(BOOL))cb {
    NSString *url = [NSString stringWithFormat:@"%@/me/player/seek?position_ms=%ld", API, (long)ms];
    [[NXHTTPClient shared] PUT:url body:nil completion:^(NSData *d, NSError *e) {
        if (cb) cb(e == nil);
    }];
}

- (void)setVolume:(NSInteger)pct completion:(void(^)(BOOL))cb {
    NSString *url = [NSString stringWithFormat:@"%@/me/player/volume?volume_percent=%ld", API, (long)pct];
    [[NXHTTPClient shared] PUT:url body:nil completion:^(NSData *d, NSError *e) {
        if (cb) cb(e == nil);
    }];
}

// ── Library ───────────────────────────────────────────────────────────────────
- (void)savedTracks:(NSInteger)limit offset:(NSInteger)offset completion:(NXTracksCallback)cb {
    NSString *url = [NSString stringWithFormat:@"%@/me/tracks?limit=%ld&offset=%ld", API, (long)limit, (long)offset];
    [[NXHTTPClient shared] GET:url completion:^(NSData *data, NSError *err) {
        if (!data) { if (cb) cb(nil, err); return; }
        NSDictionary *j = [self parseData:data];
        if (cb) cb([self tracksFromItems:j[@"items"]], nil);
    }];
}

- (void)saveTrack:(NSString *)tid completion:(void(^)(BOOL))cb {
    NSString *url = [NSString stringWithFormat:@"%@/me/tracks?ids=%@", API, tid];
    [[NXHTTPClient shared] PUT:url body:[self json:@{}] completion:^(NSData *d, NSError *e) {
        if (cb) cb(e == nil);
    }];
}

- (void)unsaveTrack:(NSString *)tid completion:(void(^)(BOOL))cb {
    // DELETE — override via NXHTTPClient
    NXSpotifyAuth *auth = [NXSpotifyAuth shared];
    [auth refreshAccessToken:^(BOOL ok) {
        NSString *url = [NSString stringWithFormat:@"%@/me/tracks?ids=%@", API, tid];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        req.HTTPMethod = @"DELETE";
        [req setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
        [[NXHTTPClient shared] sendRequest:req completion:^(NSData *d, NSError *e) {
            if (cb) cb(e == nil);
        }];
    }];
}

- (void)isTrackSaved:(NSString *)tid completion:(void(^)(BOOL))cb {
    NSString *url = [NSString stringWithFormat:@"%@/me/tracks/contains?ids=%@", API, tid];
    [[NXHTTPClient shared] GET:url completion:^(NSData *data, NSError *err) {
        if (!data) { if (cb) cb(NO); return; }
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (cb) cb(arr.count > 0 ? [arr[0] boolValue] : NO);
    }];
}

@end
