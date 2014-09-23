//
//  CHMessageViewController.h
//  Chat
//
//  Created by Michael Caputo on 3/18/14.
//
//

#import <UIKit/UIKit.h>
#import "SocketIO.h"
#import "CHSocketManager.h"
#import "HPGrowingTextView.h"
#import "DBCameraViewController.h"
#import "DBCameraContainerViewController.h"
#import "CHMessageTableDelegate.h"

@class CHGroup, CHProgressView;

@interface CHMessageViewController : UIViewController <UITextFieldDelegate,  UITextViewDelegate, UITableViewDelegate, HPGrowingTextViewDelegate, DBCameraViewControllerDelegate, CHMessageTableDelegate>

@property (nonatomic, strong) CHGroup *group;
@property (nonatomic, strong) NSString *groupId;

@property (weak, nonatomic) IBOutlet UITableView *messageTable;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomDistance;
@property (weak, nonatomic) IBOutlet UIView *messageBarView;
@property (strong, nonatomic) IBOutlet CHProgressView *progressBar;

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) HPGrowingTextView *textView;

-(void)expandImage:(UIImage *)image;

@end
