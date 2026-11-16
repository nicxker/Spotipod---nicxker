// NXSpotifyAPI.h — Spotify Web API wrapper (search, player, library)
#import <Foundation/Foundation.h>

@interface NXTrack : NSObject
@property (nonatomic, copy) NSString *trackID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, copy) NSString *uri;
@property (nonatomic) NSInteger durationMs;
+ (instancetype)fromDict:(NSDictionary *)d;
@end

@interface NXPlaybackState : NSObject
@property (nonatomic) BOOL isPlaying;
@property (nonatomic) NSInteger progressMs;
@property (nonatomic, strong) NXTrack *track;
@property (nonatomic, copy) NSString *deviceID;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic) NSInteger volumePercent;
+ (instancetype)fromDict:(NSDictionary *)d;
@end

typedef void(^NXTracksCallback)(NSArray<NXTrack *> *tracks, NSError *err);
typedef void(^NXStateCallback)(NXPlaybackState *state, NSError *err);

@interface NXSpotifyAPI : NSObject
+ (instancetype)shared;

// Search
- (void)searchTracks:(NSString *)query limit:(NSInteger)limit completion:(NXTracksCallback)cb;

// Player — controls the active Spotify device (phone/desktop)
- (void)currentPlaybackState:(NXStateCallback)cb;
- (void)play:(NSString *)spotifyURI deviceID:(NSString *)devID completion:(void(^)(BOOL))cb;
- (void)pause:(void(^)(BOOL))cb;
- (void)next:(void(^)(BOOL))cb;
- (void)previous:(void(^)(BOOL))cb;
- (void)seekTo:(NSInteger)ms completion:(void(^)(BOOL))cb;
- (void)setVolume:(NSInteger)pct completion:(void(^)(BOOL))cb;

// Library
- (void)savedTracks:(NSInteger)limit offset:(NSInteger)offset completion:(NXTracksCallback)cb;
- (void)saveTrack:(NSString *)trackID completion:(void(^)(BOOL))cb;
- (void)unsaveTrack:(NSString *)trackID completion:(void(^)(BOOL))cb;
- (void)isTrackSaved:(NSString *)trackID completion:(void(^)(BOOL))cb;
@end

