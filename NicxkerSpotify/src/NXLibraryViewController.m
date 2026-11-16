// NXLibraryViewController.m — Liked songs, paginated
#import <UIKit/UIKit.h>
#import "NXSpotifyAPI.h"

#import "NXLibraryViewController.h"

@implementation NXLibraryViewController {
    NSMutableArray<NXTrack *> *_tracks;
    NSInteger  _offset;
    BOOL       _loading;
    BOOL       _hasMore;
    NSMutableDictionary *_imageCache;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Library";
    _tracks     = [NSMutableArray array];
    _offset     = 0;
    _hasMore    = YES;
    _imageCache = [NSMutableDictionary dictionary];

    self.tableView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1];
    self.tableView.separatorColor  = [UIColor colorWithWhite:0.15 alpha:1];
    self.tableView.rowHeight       = 60;

    UIRefreshControl *rc = [[UIRefreshControl alloc] init];
    rc.tintColor = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1];
    [rc addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = rc;

    [self loadMore];
}

- (void)refresh {
    _tracks = [NSMutableArray array];
    _offset = 0;
    _hasMore = YES;
    [self loadMore];
}

- (void)loadMore {
    if (_loading || !_hasMore) return;
    _loading = YES;
    [[NXSpotifyAPI shared] savedTracks:30 offset:_offset completion:^(NSArray<NXTrack *> *tracks, NSError *err) {
        _loading = NO;
        [self.refreshControl endRefreshing];
        if (!tracks.count) { _hasMore = NO; return; }
        _offset += tracks.count;
        if (tracks.count < 30) _hasMore = NO;
        [_tracks addObjectsFromArray:tracks];
        [self.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _tracks.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    // Infinite scroll — load next page when near the end
    if (ip.row >= (NSInteger)_tracks.count - 5 && _hasMore) [self loadMore];

    static NSString *ID = @"LibCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ID];
        cell.backgroundColor        = [UIColor clearColor];
        cell.textLabel.textColor    = [UIColor whiteColor];
        cell.textLabel.font         = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1];
        cell.detailTextLabel.font   = [UIFont systemFontOfSize:12];
        cell.imageView.layer.cornerRadius = 4;
        cell.imageView.clipsToBounds = YES;
    }

    NXTrack *t = _tracks[ip.row];
    cell.textLabel.text       = t.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", t.artist, t.album];
    cell.imageView.image      = nil;

    NSString *url = t.imageURL;
    if (url) {
        UIImage *cached = _imageCache[url];
        if (cached) {
            cell.imageView.image = cached;
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                NSData *d = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
                UIImage *img = [UIImage imageWithData:d];
                if (img) {
                    if (_imageCache.count > 100) [_imageCache removeAllObjects];
                    _imageCache[url] = img;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UITableViewCell *c = [tv cellForRowAtIndexPath:ip];
                        if (c) { c.imageView.image = img; [c setNeedsLayout]; }
                    });
                }
            });
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NXTrack *t = _tracks[ip.row];
    [[NXSpotifyAPI shared] play:t.uri deviceID:nil completion:nil];
    self.tabBarController.selectedIndex = 0;
}

@end

