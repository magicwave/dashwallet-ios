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

#import "DWTxListTableViewCell.h"

#import "DWUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWTxListTableViewCell ()

@property (strong, nonatomic) IBOutlet UILabel *addressLabel;
@property (strong, nonatomic) IBOutlet UILabel *dateLabel;
@property (strong, nonatomic) IBOutlet UILabel *dashAmountLabel;
@property (strong, nonatomic) IBOutlet UILabel *fiatAmountLabel;

@property (nullable, nonatomic, weak) id<DWTransactionListDataProviderProtocol> dataProvider;
@property (nonatomic, strong) id<DWTransactionListDataItem> transactionData;

@end

@implementation DWTxListTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.addressLabel.font = [UIFont dw_fontForTextStyle:UIFontTextStyleCaption1];
    self.dateLabel.font = [UIFont dw_fontForTextStyle:UIFontTextStyleCaption2];
    self.dashAmountLabel.font = [UIFont dw_fontForTextStyle:UIFontTextStyleCaption1];
    self.fiatAmountLabel.font = [UIFont dw_fontForTextStyle:UIFontTextStyleCaption2];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentSizeCategoryDidChangeNotification:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];

    [self dw_pressedAnimation:DWPressedAnimationStrength_Light pressed:highlighted];
}

- (void)configureWithTransaction:(DSTransaction *)transaction
                    dataProvider:(id<DWTransactionListDataProviderProtocol>)dataProvider {
    NSParameterAssert(dataProvider);

    self.dataProvider = dataProvider;
    self.transactionData = [self.dataProvider transactionDataForTransaction:transaction];

    self.addressLabel.text = self.transactionData.address;
    self.dateLabel.text = [self.dataProvider dateForTransaction:transaction];
    self.fiatAmountLabel.text = self.transactionData.fiatAmount;
    [self updateDashAmountLabel];
}

#pragma mark - Notifications

- (void)contentSizeCategoryDidChangeNotification:(NSNotification *)notification {
    [self updateDashAmountLabel];
}

#pragma mark - Private

- (void)updateDashAmountLabel {
    NSParameterAssert(self.dataProvider);
    NSParameterAssert(self.transactionData);

    UIFont *font = [UIFont dw_fontForTextStyle:UIFontTextStyleCaption1];
    self.dashAmountLabel.attributedText = [self.dataProvider dashAmountStringFrom:self.transactionData
                                                                             font:font];
}

@end

NS_ASSUME_NONNULL_END