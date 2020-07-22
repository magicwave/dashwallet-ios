//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DWPasteboardAddressObserver.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

NSString *DWPasteboardObserverNotification = @"DWPasteboardObserverNotification";
static NSTimeInterval const TIMER_INTERVAL = 1.0;

@interface DWPasteboardAddressObserver ()

@property (nonatomic, assign) NSInteger changeCount;
@property (copy, nonatomic) NSArray<NSString *> *contents;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nullable, strong, nonatomic) dispatch_source_t timer;
@property (nonatomic, assign, getter=isObservingAddress) BOOL observingAddress;
@property (atomic, assign, getter=isProcessing) BOOL processing;

@end

@implementation DWPasteboardAddressObserver

- (instancetype)init {
    self = [super init];
    if (self) {
        _contents = @[];
        _changeCount = NSNotFound;
        _queue = dispatch_queue_create("DWPasteboardAddressObserver.queue", DISPATCH_QUEUE_SERIAL);

        [self checkPasteboardContentsCompletion:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActiveNotification)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [self stopIntervalObserving];
}

- (void)startIntervalObserving {
    if (self.isObservingAddress) {
        return;
    }

    self.observingAddress = YES;
    [self checkPasteboardContentsCompletion:nil];
}

- (void)stopIntervalObserving {
    if (self.isObservingAddress == NO) {
        return;
    }

    self.observingAddress = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkPasteboardContentsCompletion:) object:nil];
}

- (void)checkPasteboardContentsCompletion:(nullable void (^)(void))completion {
    NSAssert([NSThread isMainThread], @"Main thread is assumed here");

    if (self.isProcessing) {
        return;
    }

    self.processing = YES;

    if (self.changeCount == [UIPasteboard generalPasteboard].changeCount) {
        self.processing = NO;

        if (completion) {
            completion();
        }

        if (self.isObservingAddress) {
            [self performSelector:@selector(checkPasteboardContentsCompletion:) withObject:nil afterDelay:TIMER_INTERVAL];
        }

        return;
    }

    self.changeCount = [UIPasteboard generalPasteboard].changeCount;

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSMutableOrderedSet<NSString *> *resultSet = [NSMutableOrderedSet orderedSet];
    NSCharacterSet *whitespacesSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    if (pasteboard.hasStrings) {
        NSString *str = [pasteboard.string stringByTrimmingCharactersInSet:whitespacesSet];
        if (str.length > 0) {
            NSCharacterSet *separatorsSet = [NSCharacterSet alphanumericCharacterSet].invertedSet;

            [resultSet addObject:str];
            [resultSet addObjectsFromArray:[str componentsSeparatedByCharactersInSet:separatorsSet]];
        }
    }

    if (pasteboard.hasImages) {
        UIImage *img = [UIPasteboard generalPasteboard].image;
        __weak typeof(self) weakSelf = self;
        [self addressesFromImage:img
                      completion:^(NSArray<NSString *> *_Nonnull addresses) {
                          __strong typeof(weakSelf) strongSelf = weakSelf;
                          if (!strongSelf) {
                              return;
                          }

                          [resultSet addObjectsFromArray:addresses];
                          [strongSelf finishProcessingWithContents:resultSet completion:completion];
                      }];
    }
    else {
        [self finishProcessingWithContents:resultSet completion:completion];
    }
}

#pragma mark Notifications

- (void)applicationDidBecomeActiveNotification {
    [self checkPasteboardContentsCompletion:nil];
}

#pragma mark - Private

- (void)finishProcessingWithContents:(NSMutableOrderedSet<NSString *> *)resultSet
                          completion:(nullable void (^)(void))completion {
    NSAssert([NSThread isMainThread], @"Main thread is assumed here");

    self.contents = resultSet.array;

    self.processing = NO;

    if (completion) {
        completion();
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:DWPasteboardObserverNotification
                                                        object:nil];

    if (self.isObservingAddress) {
        [self performSelector:@selector(checkPasteboardContentsCompletion:) withObject:nil afterDelay:TIMER_INTERVAL];
    }
}

- (void)addressesFromImage:(UIImage *)img completion:(void (^)(NSArray<NSString *> *addresses))completion {
    NSAssert([NSThread isMainThread], @"Main thread is assumed here");

    if (img == nil) {
        if (completion) {
            completion(@[]);
        }

        return;
    }

    dispatch_async(self.queue, ^{
        NSMutableArray<NSString *> *result = [NSMutableArray array];

        @synchronized([CIContext class]) {
            NSDictionary<CIContextOption, id> *options = @{kCIContextUseSoftwareRenderer : @(YES)};
            CIContext *context = [CIContext contextWithOptions:options];
            if (!context) {
                context = [CIContext context];
            }

            CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode
                                                      context:context
                                                      options:nil];
            CGImageRef cgImage = img.CGImage;
            if (detector && cgImage) {
                NSCharacterSet *whitespacesSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                CIImage *ciImage = [CIImage imageWithCGImage:cgImage];
                NSArray<CIFeature *> *features = [detector featuresInImage:ciImage];
                for (CIQRCodeFeature *qr in features) {
                    NSString *str = [qr.messageString stringByTrimmingCharactersInSet:whitespacesSet];
                    if (str.length > 0) {
                        [result addObject:str];
                    }
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(result);
            }
        });
    });
}

@end

NS_ASSUME_NONNULL_END
