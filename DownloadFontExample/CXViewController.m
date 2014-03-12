//
//  CXViewController.m
//  DownloadFontExample
//
//  Created by XuanChen on 14-3-12.
//  Copyright (c) 2014年 XuanChen. All rights reserved.
//

#import "CXViewController.h"
#import <CoreText/CoreText.h>

#define IS_SCREEN_568H ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)
#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT (IS_SCREEN_568H ? 568 : 480)

#define BaseTag 100

typedef NS_ENUM(NSInteger, FontStatus) {
    FontStatusNotDownloaded = 0,
    FontStatusMatching,
    FontStatusDownloading,
    FontStatusDownloaded,
    FontStatusSelected
};

@interface CXViewController ()
@property (nonatomic, strong) NSMutableArray* fontNames;
@property (nonatomic, strong) NSMutableDictionary* fontStatuses; // FontName(NSString*)->FontStatus(enum FontStatus)
@property (nonatomic, strong) NSMutableDictionary* fontDownloadingProgress; // FontName(NSString*)->Progress(NSNumber*)
@property (nonatomic, strong) NSString* errorMessage;
@property (nonatomic, strong) UITableView* tvFonts;
@property (nonatomic, strong) UILabel *sampleLabel;
@end

@implementation CXViewController

#pragma mark - View Controller Lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Load data.
    [self loadData];
    
    // Set up UI.
    [self setupUI];
}


#pragma mark - Action
-(void) loadData {
    // Font names.
    self.fontNames = [@[@"STXingkai-SC-Light", @"DFWaWaSC-W5", @"FZLTXHK--GBK1-0", @"STLibian-SC-Regular", @"LiHeiPro", @"HiraginoSansGB-W3"] mutableCopy];
    // Font status and font downloading progress.
    self.fontStatuses = [[NSMutableDictionary alloc] init];
    self.fontDownloadingProgress = [[NSMutableDictionary alloc] init];
    for (NSString* fontName in self.fontNames) {
        // Set font status.
        if ([self isFontDownloaded:fontName]) {
            [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusDownloaded] forKey:fontName];
        }
        else {
            [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusNotDownloaded] forKey:fontName];
        }
        
        // Set font downloading progress.
        [self.fontDownloadingProgress setObject:[NSNumber numberWithFloat:0.0] forKey:fontName];
    }
    
}

-(void) setupUI {
    // Font table view.
    self.tvFonts = [[UITableView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT-200, SCREEN_WIDTH, 200) style:UITableViewStylePlain];
    [self.tvFonts setDelegate:self];
    [self.tvFonts setDataSource:self];
    [self.tvFonts setBackgroundColor:[UIColor grayColor]];
    [self.tvFonts setBackgroundView:nil];
    [self.view addSubview:self.tvFonts];
    
    // Sample label.
    self.sampleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, SCREEN_WIDTH, 30)];
    [self.sampleLabel setText:@"This is a sample label."];
    [self.sampleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.sampleLabel];
    
    
}


-(void) loadFont:(UIButton*)sender {
    NSInteger index = sender.tag-BaseTag;
    NSString* fontName = [self.fontNames objectAtIndex:index];
    NSLog(@"Load Font: %@", fontName);
    
    // Update font status.
    [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusMatching] forKey:fontName];
    // Refresh table view cell.
    [self.tvFonts reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
    
    // Create a dictionary with the font's PostScript name.
	NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithObjectsAndKeys:fontName, kCTFontNameAttribute, nil];
    // Create a new font descriptor reference from the attributes dictionary.
	CTFontDescriptorRef desc = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attrs);
    
    NSMutableArray *descs = [NSMutableArray arrayWithCapacity:0];
    [descs addObject:(__bridge id)desc];
    CFRelease(desc);
    
    __block BOOL errorDuringDownload = NO;
    
    // Start processing the font descriptor..
    // This function returns immediately, but can potentially take long time to process.
    // The progress is notified via the callback block of CTFontDescriptorProgressHandler type.
    // See CTFontDescriptor.h for the list of progress states and keys for progressParameter dictionary.
    CTFontDescriptorMatchFontDescriptorsWithProgressHandler( (__bridge CFArrayRef)descs, NULL,  ^(CTFontDescriptorMatchingState state, CFDictionaryRef progressParameter) {
        
        double progressValue = [[(__bridge NSDictionary *)progressParameter objectForKey:(id)kCTFontDescriptorMatchingPercentage] doubleValue];
        
        if (state == kCTFontDescriptorMatchingDidBegin) {
            dispatch_async(dispatch_get_main_queue(), ^ {
                
                
                NSLog(@"Begin Matching...");
            });
        }
        else if (state == kCTFontDescriptorMatchingDidFinish) {
            dispatch_async(dispatch_get_main_queue(), ^ {

                // Log the font URL in the console
				CTFontRef fontRef = CTFontCreateWithName((__bridge CFStringRef)fontName, 0., NULL);
                CFStringRef fontURL = CTFontCopyAttribute(fontRef, kCTFontURLAttribute);
				NSLog(@"Font URL: %@", (__bridge NSURL*)(fontURL));
                CFRelease(fontURL);
				CFRelease(fontRef);
                
                if (!errorDuringDownload) {
                    // Update font status.
                    [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusDownloaded] forKey:fontName];
                    // Refresh table view cell.
                    [self.tvFonts reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
                    
					NSLog(@"%@ Downloaded.", fontName);
				}
            });
        }
        else if (state == kCTFontDescriptorMatchingWillBeginDownloading) {
            dispatch_async(dispatch_get_main_queue(), ^ {
                
                // Update font status.
                [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusDownloading] forKey:fontName];
                // Update font downloading progress.
                [self.fontDownloadingProgress setObject:[NSNumber numberWithFloat:0.0] forKey:fontName];
                // Refresh table view cell.
                [self.tvFonts reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
                
                NSLog(@"Begin Downloading...");
            });
        }
        else if (state == kCTFontDescriptorMatchingDidFinishDownloading) {
            dispatch_async(dispatch_get_main_queue(), ^ {
                
                NSLog(@"Finish Downloading.");
            });
        }
        else if (state == kCTFontDescriptorMatchingDownloading) {
            dispatch_async(dispatch_get_main_queue(), ^ {
                
                // Update font downloading progress.
                [self.fontDownloadingProgress setObject:[NSNumber numberWithFloat:progressValue/100.0] forKey:fontName];
                // Refresh table view cell.
                [self.tvFonts reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
                
                NSLog(@"Downloading %.0f%% Complete.", progressValue);
            });
        }
        else if (state == kCTFontDescriptorMatchingDidFailWithError) {
            // An error has occurred. Get the error message
            NSError *error = [(__bridge NSDictionary *)progressParameter objectForKey:(id)kCTFontDescriptorMatchingError];
            if (error != nil) {
                self.errorMessage = [error description];
            } else {
                self.errorMessage = @"ERROR MESSAGE IS NOT AVAILABLE!";
            }
            // Set our flag
            errorDuringDownload = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^ {
                // Update font status.
                [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusNotDownloaded] forKey:fontName];
                // Update font downloading progress.
                [self.fontDownloadingProgress setObject:[NSNumber numberWithFloat:0.0] forKey:fontName];
                // Refresh table view cell.
                [self.tvFonts reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
                
				NSLog(@"Download error: %@", self.errorMessage);
			});
        }
        
        return (bool)YES;
    });
    
}

#pragma mark - Utility
-(BOOL) isFontDownloaded:(NSString*)fontName {
    UIFont* aFont = [UIFont fontWithName:fontName size:12.0];
    if (aFont && ([aFont.fontName compare:fontName] == NSOrderedSame
                  || [aFont.familyName compare:fontName] == NSOrderedSame)) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Table View Delegate
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString* fontName = [self.fontNames objectAtIndex:indexPath.row];
    if ([[self.fontStatuses objectForKey:fontName] integerValue] == FontStatusDownloaded) {
        
        for (NSString* kFontName in [self.fontStatuses allKeys]) {
            if ([[self.fontStatuses objectForKey:kFontName] integerValue] == FontStatusSelected) {
                [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusDownloaded] forKey:kFontName];
            }
        }
        [self.fontStatuses setObject:[NSNumber numberWithInteger:FontStatusSelected] forKey:fontName];
        // Refresh table view cells.
        [self.tvFonts reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
        
#warning Set other text font here.
        NSLog(@"Selected font: %@", fontName);
        [self.sampleLabel setFont:[UIFont fontWithName:fontName size:14.0]];
        
    }
    
    
}

#pragma mark - Table View Datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.fontNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    /*
     //
     static NSString *CellIdentifier = @"CellIdentifierFont";
     UITableViewCell *cell = nil;
     cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
     if (cell == nil) {
     cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
     }
     */
    
    // Reused cell will reuse the font info and accessory view info, this may cause some UI bugs.
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    NSString* fontName = [self.fontNames objectAtIndex:indexPath.row];
    FontStatus fontStatus = [[self.fontStatuses objectForKey:fontName] integerValue];
    if (fontStatus == FontStatusDownloaded) { // downloaded
        [cell.textLabel setFont:[UIFont fontWithName:fontName size:17.0]];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
    }
    else if (fontStatus == FontStatusDownloading) { // downloading...
        UIProgressView* progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 0, 50, 2)];
        [progressView setProgress:[[self.fontDownloadingProgress objectForKey:fontName] floatValue] animated:YES];
        cell.accessoryView = progressView;
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    else if (fontStatus == FontStatusMatching) { // Matching...
        UIActivityIndicatorView* spinView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        [spinView startAnimating];
        cell.accessoryView = spinView;
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    else if (fontStatus == FontStatusSelected) { // Selected.
        [cell.textLabel setFont:[UIFont fontWithName:fontName size:17.0]];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
    }
    else if (fontStatus == FontStatusNotDownloaded) { // Not downloaded.
        // Download button.
        UIButton* btnDownloadFont = [UIButton buttonWithType:UIButtonTypeCustom];
        [btnDownloadFont setFrame:CGRectMake(0, 0, 54, 27)];
        [btnDownloadFont setTitle:@"Load" forState:UIControlStateNormal];
        [btnDownloadFont setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
        [btnDownloadFont setBackgroundColor:[UIColor brownColor]];
        btnDownloadFont.tag = BaseTag + indexPath.row;
        [btnDownloadFont addTarget:self action:@selector(loadFont:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = btnDownloadFont;
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    
    
    [cell setBackgroundColor:[UIColor grayColor]];
    cell.textLabel.text = fontName;
    
    return cell;
}

@end
