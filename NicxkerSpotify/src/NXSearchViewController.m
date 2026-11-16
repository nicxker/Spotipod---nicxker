// NXSearchViewController.m — Search with debounce, reusable cells, image cache
#import <UIKit/UIKit.h>
#import "NXSpotifyAPI.h"
#import "NXTrackCell.h"

#import "NXSearchViewController.h"

@implementation NXSearchViewController {
    UISearchBar          *_searchBar;
    NSArray<NXTrack *>   *_results;
    NSTimer              *_debounce;
    NSMutableDictionary  *_imageCache;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Search";
    _results = @[];
    _imageCache = [NSMutableDictionary dictionary];

    self.tableView.backgroundColor   = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1];
    self.tableView.separatorColor    = [UIColor colorWithWhite:0.15 alpha:1];
    self.tableView.rowHeight         = 60;

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _searchBar.delegate     = self;
    _searchBar.placeholder  = @"Songs, artists...";
    _searchBar.barStyle     = UIBarStyleBlack;
    _searchBar.tintColor    = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1];
    self.tableView.tableHeaderView = _searchBar;
}

// ── Search with 400ms debounce to avoid hammering API ─────────────────────────
- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    [_debounce invalidate];
    if (text.length < 2) { _results = @[]; [self.tableView reloadData]; return; }
    _debounce = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self
                 selector:@selector(doSearch) userInfo:nil repeats:NO];
}

- (void)doSearch {
    NSString *q = _searchBar.text;
    if (q.length < 2) return;
    [[NXSpotifyAPI shared] searchTracks:q limit:30 completion:^(NSArray<NXTrack *> *tracks, NSError *err) {
        _results = tracks ?: @[];
        [self.tableView reloadData];
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    [sb resignFirstResponder];
    [self doSearch];
}

// ── Table ─────────────────────────────────────────────────────────────────────
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _results.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *ID = @"TrackCell";
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

    NXTrack *t = _results[ip.row];
    cell.textLabel.text       = t.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", t.artist, t.album];
    cell.imageView.image      = nil;

    // Async thumbnail load with cache
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
                    if (_imageCache.count > 50) [_imageCache removeAllObjects];
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
    NXTrack *t = _results[ip.row];
    [[NXSpotifyAPI shared] play:t.uri deviceID:nil completion:nil];
    // Switch to Now Playing tab
    self.tabBarController.selectedIndex = 0;
}

@end

