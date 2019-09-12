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

#import "DWAuthenticationManager.h"

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DWAuthenticationManager

+ (void)authenticateWithPrompt:(nullable NSString *)prompt
                    biometrics:(BOOL)useBiometrics
                alertIfLockout:(BOOL)alertIfLockout
                    completion:(nullable PinCompletionBlock)completion {
    DSAuthenticationManager *authManager = [DSAuthenticationManager sharedInstance];
    if (useBiometrics && [authManager isBiometricAuthenticationAllowed]) {
        [[AppDelegate instance] setBlurringScreenDisabledOneTime];
    }

    [authManager authenticateWithPrompt:prompt
                             andTouchId:useBiometrics
                         alertIfLockout:alertIfLockout
                             completion:completion];
}

+ (void)authenticateUsingBiometricsOnlyWithPrompt:(nullable NSString *)prompt
                                       completion:(PinCompletionBlock)completion {
    DSAuthenticationManager *authManager = [DSAuthenticationManager sharedInstance];
    if ([authManager isBiometricAuthenticationAllowed]) {
        [[AppDelegate instance] setBlurringScreenDisabledOneTime];
    }

    [authManager authenticateUsingBiometricsOnlyWithPrompt:prompt completion:completion];
}

@end

NS_ASSUME_NONNULL_END
