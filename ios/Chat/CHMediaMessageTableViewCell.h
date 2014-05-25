//
//  CHMediaMessageTableViewCell.h
//  Chat
//
//  Created by Michael Caputo on 5/20/14.
//
//

#import <UIKit/UIKit.h>
#import "CHMessageTableViewCell.h"

@class CHMessageViewController;

@interface CHMediaMessageTableViewCell : CHMessageTableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *mediaMessageImageView;

@property NSDate *dateSent;

- (id)initWithCoder:(NSCoder *)aDecoder;
-(void)setupGestureWithTableView: (CHMessageViewController *)tableView;

@end
