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

#import "DWPayViewController.h"

#import "DWConfirmPaymentViewController.h"
#import "DWContactsViewController.h"
#import "DWPayModelProtocol.h"
#import "DWPayOptionModel.h"
#import "DWPayTableViewCell.h"
#import "DWPaymentInputBuilder.h"
#import "DWPaymentProcessor.h"
#import "DWQRScanModel.h"
#import "DWQRScanViewController.h"
#import "DWSendAmountViewController.h"
#import "DWUIKit.h"
#import "DWUserPayTableViewCell.h"
#import "UIView+DWHUD.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWPayViewController () <UITableViewDataSource, UITableViewDelegate, DWUserPayTableViewCellDelegate, DWContactsViewControllerPayDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation DWPayViewController

+ (instancetype)controllerWithModel:(id<DWPayModelProtocol>)payModel
                       dataProvider:(id<DWTransactionListDataProviderProtocol>)dataProvider {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Pay" bundle:nil];
    DWPayViewController *controller = [storyboard instantiateInitialViewController];
    controller.payModel = payModel;
    controller.dataProvider = dataProvider;

    return controller;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.payModel updateFrequentContacts];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.tableView flashScrollIndicators];

    [self.payModel startPasteboardIntervalObserving];

    if (self.demoMode) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performPayToPasteboardAction];
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self.payModel stopPasteboardIntervalObserving];
}

- (void)payViewControllerDidHidePaymentResultToContact:(nullable id<DWDPBasicUserItem>)contact {
    [self.delegate payViewControllerDidFinishPayment:self contact:contact];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.payModel.options.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DWPayOptionModel *option = self.payModel.options[indexPath.row];
    if (option.type == DWPayOptionModelType_DashPayUser) {
        DWUserPayTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:DWUserPayTableViewCell.dw_reuseIdentifier
                                                                       forIndexPath:indexPath];
        cell.model = option;
        cell.delegate = self;
        return cell;
    }
    else {
        DWPayTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:DWPayTableViewCell.dw_reuseIdentifier
                                                                   forIndexPath:indexPath];
        cell.model = option;
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    DWPayOptionModel *option = self.payModel.options[indexPath.row];
    switch (option.type) {
        case DWPayOptionModelType_ScanQR: {
            [self performScanQRCodeAction];

            break;
        }
        case DWPayOptionModelType_Pasteboard: {
            [self performPayToPasteboardAction];

            break;
        }
        case DWPayOptionModelType_NFC: {
            [self performNFCReadingAction];

            break;
        }
        case DWPayOptionModelType_DashPayUser: {
            DWContactsViewController *contactsController = [[DWContactsViewController alloc] initWithPayModel:self.payModel dataProvider:self.dataProvider];
            contactsController.intent = DWContactsControllerIntent_PayToSelector;
            contactsController.payDelegate = self;
            [self.navigationController pushViewController:contactsController animated:YES];

            break;
        }
    }
}

#pragma mark - DWUserPayTableViewCellDelegate

- (void)userPayTableViewCell:(DWUserPayTableViewCell *)cell didSelectUserItem:(id<DWDPBasicUserItem>)item {
    [self performPayToUser:item];
}

#pragma mark - DWContactsViewControllerPayDelegate

- (void)contactsViewController:(DWContactsViewController *)controller payToItem:(id<DWDPBasicUserItem>)item {
    [self performPayToUser:item];
}

#pragma mark - Private

- (void)setupView {
    NSString *cellId;
    NSArray<NSString *> *cellIds = @[
        DWPayTableViewCell.dw_reuseIdentifier,
        DWUserPayTableViewCell.dw_reuseIdentifier,
    ];
    for (NSString *cellId in cellIds) {
        UINib *nib = [UINib nibWithNibName:cellId bundle:nil];
        NSParameterAssert(nib);
        [self.tableView registerNib:nib forCellReuseIdentifier:cellId];
    }

    self.tableView.tableFooterView = [[UIView alloc] init];
}

@end

NS_ASSUME_NONNULL_END
