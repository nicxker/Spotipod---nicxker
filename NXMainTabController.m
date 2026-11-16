// NXMainTabController.m — Tab bar: Now Playing / Search / Library
#import <UIKit/UIKit.h>
#import "NXPlayerViewController.h"
#import "NXSearchViewController.h"
#import "NXLibraryViewController.h"

#import "NXMainTabController.h"

@implementation NXMainTabController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Compatible con la barra de iOS 6
    if ([self.tabBar respondsToSelector:@selector(setSelectedImageTintColor:)]) {
        self.tabBar.selectedImageTintColor = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1];
    }

    NXPlayerViewController  *player  = [[NXPlayerViewController alloc] init];
    NXSearchViewController  *search  = [[NXSearchViewController alloc] init];
    NXLibraryViewController *library = [[NXLibraryViewController alloc] init];

    player.tabBarItem  = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];
    player.tabBarItem.title = @"Now Playing";
    search.tabBarItem  = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:1];
    library.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:2];
    library.tabBarItem.title = @"Library";

    UINavigationController *searchNav  = [[UINavigationController alloc] initWithRootViewController:search];
    UINavigationController *libraryNav = [[UINavigationController alloc] initWithRootViewController:library];
    [self styleNavBar:searchNav.navigationBar];
    [self styleNavBar:libraryNav.navigationBar];

    self.viewControllers = @[player, searchNav, libraryNav];
}

- (void)styleNavBar:(UINavigationBar *)bar {
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = NO;
    bar.tintColor = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1];
}

@end
