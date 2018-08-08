//
//  JWPgyerUpgradeManager.h
//  PgyerUpgradeManager
//
//  Created by Justin.wang on 2018/6/1.
//

#import <Foundation/Foundation.h>

@interface JWPgyerUpgradeManager : NSObject

@property (nonatomic, assign) BOOL isForce;

+ (instancetype)sharedManager;

- (void)fetchUpgradeInfoWithAppShortcut:(NSString *)shortcut
                                 apiKey:(NSString *)apiKey;

@end

