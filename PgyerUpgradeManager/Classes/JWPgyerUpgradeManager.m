//
//  JWPgyerUpgradeManager.m
//  PgyerUpgradeManager
//
//  Created by Justin.wang on 2018/6/1.
//

#import "JWPgyerUpgradeManager.h"

#import <AFNetworking/AFNetworking.h>

static NSString * const kShortcutUrl = @"http://www.pgyer.com/apiv1/app/getAppKeyByShortcut";
static NSString * const kAppViewUrl  = @"http://www.pgyer.com/apiv1/app/view";
static NSString * const kInstallFormat = @"itms-services://?action=download-manifest&url=https://www.pgyer.com/app/plist/%@";
static NSString * kUpdateTimeKey = @"kPgyerUpdateTimeKey";

@interface JWPgyerUpgradeManager ()

@property (nonatomic, copy  ) NSString *apiKey;
@property (nonatomic, copy  ) NSString *appKey;
@property (nonatomic, assign) BOOL     isFetching;

@end

@implementation JWPgyerUpgradeManager

+ (instancetype)sharedManager {
    static JWPgyerUpgradeManager *sharedManager = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (void)fetchUpgradeInfoWithAppShortcut:(NSString *)shortcut apiKey:(NSString *)apiKey {
    if (self.isFetching) {
        return;
    }
    NSParameterAssert(shortcut);
    NSParameterAssert(apiKey);
    self.apiKey = apiKey;
    NSDictionary *dic = @{@"shortcut" : shortcut,
                          @"_api_key" : apiKey};
    self.isFetching = YES;
    [[AFHTTPSessionManager manager] POST:kShortcutUrl
                              parameters:dic
               constructingBodyWithBlock:nil
                                progress:nil
                                 success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                                     self.appKey = responseObject[@"data"][@"appKey"];
                                     [self fetchAppDetialInfo];
                                 } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                     self.isFetching = NO;
                                 }];
}

- (void)fetchAppDetialInfo {
    NSParameterAssert(self.appKey);
    NSDictionary *dic = @{@"aKey"     : self.appKey,
                          @"_api_key" : self.apiKey};
    [[AFHTTPSessionManager manager] POST:kAppViewUrl parameters:dic constructingBodyWithBlock:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        self.isFetching = NO;
        NSDate *appUpdateDate = [self dateFromString:responseObject[@"data"][@"appUpdated"]];
        if (!appUpdateDate) {
            return;
        }
        NSDate *bundleCreateDate = [[NSUserDefaults standardUserDefaults] objectForKey:kUpdateTimeKey];
        if (!bundleCreateDate) {
            [[NSUserDefaults standardUserDefaults] setObject:appUpdateDate forKey:kUpdateTimeKey];
            return;
        }
        NSComparisonResult result = [appUpdateDate compare:bundleCreateDate];
        if (result == NSOrderedSame || result == NSOrderedAscending) {
            return;
        }
        self.isFetching = NO;
        [self gotoInstallWithDate:appUpdateDate updateDesc:responseObject[@"data"][@"appUpdateDescription"]];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        self.isFetching = NO;
    }];
}

- (void)gotoInstallWithDate:(NSDate *)date updateDesc:(NSString *)updateDesc {
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:kUpdateTimeKey];
    NSString *message;
    if (updateDesc.length > 0) {
        message = [NSString stringWithFormat:@"蒲公英上有新版本, 更新内容为\n%@", updateDesc];
    } else {
        message = @"蒲公英上有新版本啦";
    }
    [self showWithTitle:nil
                message:message
      cancelButtonTitle:@"忽略"
            cancelBlock:nil
       otherButtonTitle:@"立即更新"
          otherTapBlock:^{
              [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:kInstallFormat, self.appKey]]];
          }];
}

- (NSDate *)dateFromString:(NSString *)string {
    NSDate *date;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.timeZone = [NSTimeZone defaultTimeZone];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    date = [dateFormatter dateFromString:string];
    return date;
}

- (void)showWithTitle:(NSString *)title
              message:(NSString *)message
    cancelButtonTitle:(NSString *)cancelButtonTitle
          cancelBlock:(dispatch_block_t)cancelBlock
     otherButtonTitle:(NSString *)otherButtonTitle
        otherTapBlock:(dispatch_block_t)otherTapBlock {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    if (cancelButtonTitle.length > 0) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 if (cancelBlock) {
                                                                     cancelBlock ? cancelBlock() : nil;
                                                                 }
                                                             }];
        [alertController addAction:cancelAction];
    }
    if (otherButtonTitle.length > 0) {
        UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherButtonTitle
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                otherTapBlock ? otherTapBlock() : nil;
                                                            }];
        [alertController addAction:otherAction];
    }
    
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alertController animated:YES completion:nil];
}

@end

