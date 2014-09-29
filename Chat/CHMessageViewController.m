//
//  CHMessageViewController.m
//  Chat
//
//  Created by Michael Caputo on 3/18/14.
//
//

#import "CHMessageViewController.h"
#import "CHMessage.h"
#import "CHUser.h"
#import "CHGroup.h"
#import "CHMessageTableViewCell.h"
#import "CHBackgroundContext.h"
#import "URBMediaFocusViewController.h"
#import "CHProgressView.h"
#import "CHMessageDetailTableViewController.h"
#import "UIAlertView+PromiseKit.h"
#import "TSMessage.h"

#define kDefaultContentOffset self.navigationController.navigationBar.frame.size.height + 20

NSString *const CHMesssageCellIdentifier = @"CHMessageTableViewCell";
NSString *const CHOwnMesssageCellIdentifier = @"CHOwnMessageTableViewCell";

@interface CHMessageViewController ()

@property (nonatomic, assign) NSInteger page;
@property (atomic, copy) NSArray *messageIDs;
@property (nonatomic, strong) NSMutableOrderedSet *messages;
@property (nonatomic, copy) void (^loadInNewMessages)(NSArray *messageIDs);
@property (nonatomic, strong) URBMediaFocusViewController *mediaFocus;
@property (nonatomic, strong) UIImage *media;
@property (nonatomic, strong) CHProgressView *progressBar;
@property (nonatomic, strong) UIRefreshControl *refresh;

@end

@implementation CHMessageViewController

#pragma mark - View Lifecycle

- (instancetype)initWithGroup:(CHGroup *)group;
{
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
        self.page = 0;
        self.group = group;
        self.messages = [NSMutableOrderedSet orderedSet];
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.title = self.group.name;
        self.view.backgroundColor = kLightBackgroundColor;
        self.tableView.backgroundColor = kLightBackgroundColor;
        self.textView.placeholder = @"Send FastChat";
        [self.leftButton setImage:[UIImage imageNamed:@"Attach"] forState:UIControlStateNormal];
        self.leftButton.imageEdgeInsets = UIEdgeInsetsMake(6, 7, 14, 7);
        
        UIBarButtonItem *details = [[UIBarButtonItem alloc] initWithTitle:@"Details"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(detailBarButtonTapped:)];
        self.navigationItem.rightBarButtonItem = details;
        
        
        [self.tableView registerNib:[UINib nibWithNibName:@"CHMessageTableViewCell" bundle:nil]
             forCellReuseIdentifier:CHMesssageCellIdentifier];

        [self.tableView registerNib:[UINib nibWithNibName:@"CHOwnMessageTableViewCell" bundle:nil]
             forCellReuseIdentifier:CHOwnMesssageCellIdentifier];
        
        __weak CHMessageViewController *this = self;
        self.loadInNewMessages = ^(NSArray *messageIDs) {
            __strong CHMessageViewController *strongSelf = this;
            if(strongSelf) {
                strongSelf.messageIDs = messageIDs;
                @synchronized(strongSelf) {
                    for (NSManagedObjectID *anID in strongSelf.messageIDs) {
                        
                        CHMessage *message = [CHMessage objectID:anID toContext:[NSManagedObjectContext MR_defaultContext]];
                        if (message) {
                            [strongSelf.messages addObject:message];
                        }
                    }
                    strongSelf.messageIDs = nil;
                }
                [strongSelf.tableView reloadData];
            }
        };
        
        [self shouldRefresh:self.refresh];
        
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated;
{
    [super viewWillAppear:animated];
    self.textView.text = self.group.unsentText;
}

- (void)viewWillDisappear:(BOOL)animated;
{
    [super viewWillDisappear:animated];
    self.group.unsentText = self.textView.text;
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    CHMessage *message = self.messages[indexPath.row];
    CHMessageTableViewCell *cell;
    UIColor *color = [UIColor whiteColor];
    CHUser *author = message.getAuthorNonRecursive;

    if ( [message.author isEqual:[CHUser currentUser]] ) {
        cell = [tableView dequeueReusableCellWithIdentifier:CHOwnMesssageCellIdentifier forIndexPath:indexPath];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:CHMesssageCellIdentifier forIndexPath:indexPath];
        color = [UIColor blackColor];
    }
    
    cell.transform = self.tableView.transform;

    NSDictionary *attributes = @{NSForegroundColorAttributeName: color,
                                 NSFontAttributeName: [UIFont systemFontOfSize:16.0]};
    cell.messageTextView.text = nil;
    cell.messageTextView.attributedText = nil;
    cell.messageTextView.attributedText = [[NSAttributedString alloc] initWithString:message.text ? message.text : @""
                                                                          attributes:attributes];
    cell.authorLabel.text = author.username;
    cell.timestampLabel.text = [self formatDate:message.sent];
    
    static UIImage *defaultImage = nil;
    if (!defaultImage) {
        defaultImage = [UIImage imageNamed:@"NoAvatar"];
    }
    
    cell.authorLabel.textColor = author.color;
    
    /**
     * The author may actually not exist if you have a message
     * from the system.
     */
    if (author) {
        author.avatar.then(^(CHUser *user, UIImage *avatar) {
            cell.avatarImageView.image = avatar;
        }).catch(^(NSError *error){
            cell.avatarImageView.image = defaultImage;
        });
    } else {
        cell.authorLabel.textColor = color;
        cell.avatarImageView.image = defaultImage;
    }
    
    /// Remove all gesture recognizers on cell reuse
    for (UIGestureRecognizer *recognizer in cell.gestureRecognizers) {
        [cell removeGestureRecognizer:recognizer];
    }
    if (message.hasMediaValue) {
        message.media.then(^(UIImage *image){
            CGSize size = [self boundsForImage:image];
            NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
            textAttachment.image = image;
            textAttachment.bounds = CGRectMake(0, 0, size.width, size.height);
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageTapped:)];
            [cell.messageTextView addGestureRecognizer:tap];
            
            NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:message.text]];
            [string appendAttributedString:[NSAttributedString attributedStringWithAttachment:textAttachment]];
            [string addAttributes:attributes range:NSMakeRange(0, string.length)];
            cell.messageTextView.attributedText = string;
        });
    }
    
    return cell;
}

/**
 * Let's help the tableview out some. Most people send 1 line messages, and that makes our
 * cells 49 pixels high.
 */
- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    CHMessage *message = self.messages[indexPath.row];
    if (message.rowHeightValue > 0) {
        return message.rowHeightValue;
    }
    return 75;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    CHMessage *message = self.messages[indexPath.row];
    if (message.rowHeightValue > 0) {
        return message.rowHeightValue;
    }
    
    CGRect rect = [message.text boundingRectWithSize:CGSizeMake(205 - 16, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:16]}
                                             context:nil];
    
    CGFloat height = rect.size.height;
    // Adding 45.0 to fix the bug where messages of certain lengths don't size the cell properly.
    if( message.hasMedia.boolValue) {
        height += 150.0f;
    }
    height += 45.0f;
    
    message.rowHeightValue = height;
    return height;
}


- (NSString *)formatDate:(NSDate *)date;
{
    if (!date) {
        return nil;
    }
    
    static NSDateFormatter *timestampFormatter = nil;
    if (!timestampFormatter) {
        timestampFormatter = [[NSDateFormatter alloc] init];
        [timestampFormatter setDateStyle:NSDateFormatterLongStyle];
        timestampFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        timestampFormatter.dateFormat = @"MMM dd, HH:mm";
    }
    return [timestampFormatter stringFromDate:date];
}

- (CGSize)boundsForImage:(UIImage *)image;
{
    CGFloat height = image.size.height;
    CGFloat width = image.size.width;
    CGFloat max = 150.0;
    
    if (height > width && height > max) {
        CGFloat ratio = height / max;
        height = height / ratio;
        width = width / ratio;
    } else if (width >= height && width > max) {
        CGFloat ratio = width / max;
        height = height / ratio;
        width = width / ratio;
    }
    return CGSizeMake(width, height);
}

- (void)imageTapped:(UITapGestureRecognizer *)sender;
{
    CGPoint tap = [sender locationInView:sender.view];
    
    UIView *aView = sender.view;
    UITableViewCell *cell = nil;
    while (cell == nil) {
        if ([aView isKindOfClass:[UITableViewCell class]]) {
            cell = (UITableViewCell *)aView;
        }
        aView = aView.superview;
    }
    
    if (cell) {
        NSIndexPath *path = [self.tableView indexPathForCell:cell];
        CHMessage *message = self.messages[path.row];
        message.media.then(^(UIImage *image) {
            CGSize size = [self boundsForImage:image];
            if (tap.x < size.width && tap.y < size.height) {
                self.mediaFocus = [[URBMediaFocusViewController alloc] init];
                [self.mediaFocus showImage:image fromView:self.view];
            }
        });
    }
}

- (void)getMostRecentMessages:(NSNotification *)note;
{
    id q = [CHBackgroundContext backgroundContext].queue;
    NSManagedObjectContext *context = [CHBackgroundContext backgroundContext].context;
    
    dispatch_promise_on(q, ^{
        return [self.group remoteMessagesAtPage:0];
    })
    .thenOn(q, ^{
        [context reset];
        NSArray *final = [self localMessagesAtPage:0 context:context];
        NSMutableArray *newMessageIDS = [NSMutableArray array];
        for (CHMessage *message in final) {
            [newMessageIDS addObject:message.actualObjectId];
        }
        return newMessageIDS;
    })
    .then(_loadInNewMessages);
}

- (void)shouldRefresh:(UIRefreshControl *)sender;
{
    [self messagesAtPage:_page]
    .then(_loadInNewMessages)
    .catch(^(NSError *error) {
        DLog(@"Error: %@", error);
    }).finally(^{
        self.page++;
        [self.refresh endRefreshing];
    });
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [super scrollViewDidScroll:scrollView];
    if ((scrollView.contentOffset.y + scrollView.frame.size.height) >= scrollView.contentSize.height + 50) {
        DLog(@"LOAD MORE DATA");
    }
}

#pragma mark Socket.io

- (void)newMessageNotification:(NSNotification *)note;
{
    CHMessage *message = note.userInfo[CHNotificationPayloadKey];
    if (message && [message.group isEqual:self.group]) {
        [self addMessage:message];
    } else {
        [self otherGroupMessage:message];
    }
}

- (void)addMessage:(CHMessage *)foreignMessage;
{
    CHMessage *message = [CHMessage object:foreignMessage toContext:[NSManagedObjectContext MR_defaultContext]];
    if (message) {
        [self addMessageToTableView:message];
    }
}

- (void)addMessageToTableView:(CHMessage *)message;
{
    [self.tableView beginUpdates];
    [self.messages insertObject:message atIndex:0];
    NSIndexPath *path = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionTop animated:YES];
    [self.tableView endUpdates];
}


#pragma mark - Messages

/**
 * The idea here is simple. We start off with an immediate small batch of xx messages
 * (it has to be enough so you can't see the top of the screen), then because most often
 * this will probaby be the case, we immediatly fetch the next YY. This is also good if
 * people are sending messages and you want to get the latest).
 *
 * When we "fetch", we always do it from the background, and then return the ObjectID's to
 * the messageID array. The main thread will use these ID's to do the fetch, which is almost
 * instant in Core Data (hash lookup and probably cached).
 *
 * When the UI gets the messageID's that are waiting, it then queues the next background
 * fetch to get the next batch (local + server). This ensures we are always 1 step ahead,
 * and things run fast.
 */
- (PMKPromise *)messagesAtPage:(NSUInteger)page;
{
    id q = [CHBackgroundContext backgroundContext].queue;
    NSManagedObjectContext *context = [CHBackgroundContext backgroundContext].context;
    
    return dispatch_promise_on(q, ^{
        return [self localMessagesAtPage:page context:context];
    }).thenOn(q, ^(NSArray *local){
        NSMutableArray *newMessageIDS = [NSMutableArray array];
        for (CHMessage *message in local) {
            [newMessageIDS addObject:message.actualObjectId];
        }
        return newMessageIDS;
    }).then(_loadInNewMessages)
    .thenOn(q, ^{
        return [self.group remoteMessagesAtPage:self.page];
    }).thenOn(q, ^{
        [context reset];
        NSMutableArray *newMessageIDS = [NSMutableArray array];
        NSArray *final = [self localMessagesAtPage:page context:context];
        for (CHMessage *message in final) {
            [newMessageIDS addObject:message.actualObjectId];
        }
        return newMessageIDS;
    });
}

- (NSArray *)localMessagesAtPage:(NSUInteger)page context:(NSManagedObjectContext *)context;
{
    NSPredicate *messages = [NSPredicate predicateWithFormat:@"SELF.group == %@ AND SELF.chID != nil", self.group];
    NSFetchRequest *fetchRequest = [CHMessage MR_requestAllWithPredicate:messages];
    [fetchRequest setFetchLimit:30];
    [fetchRequest setFetchOffset:page * 30];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"sent" ascending:NO];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    return [CHMessage MR_executeFetchRequest:fetchRequest inContext:context];
}

#pragma mark - Send Message
- (void)didPressRightButton:(id)sender;
{
    [self startSendingMessage];
    NSString *msg = self.textView.text;
    
    if ( !msg.length ) {
        return;
    }
    
    CHUser *user = [CHUser currentUser];
    
    CHMessage *newMessage = [CHMessage MR_createEntity];
    newMessage.text = msg;
    newMessage.author = user;
    newMessage.group = self.group;
    newMessage.sent = [NSDate date];
    
    if (self.media) {
        newMessage.hasMedia = @YES;
        newMessage.theMediaSent = self.media;
    }
    
    [self.group addMessagesObject:newMessage];
    
    [user sendMessage:newMessage toGroup:self.group].then(^(CHMessage *mes) {
        [self addMessageToTableView:mes];
    }).catch(^(NSError *error) {
        return [[[UIAlertView alloc] initWithTitle:@"Error!"
                                           message:error.localizedDescription
                                          delegate:nil
                                 cancelButtonTitle:@"Darn"
                                 otherButtonTitles:nil] promise];
    }).finally(^{
        [self endSendingMessage];
    });
    
    self.textView.text = @"";
}

#pragma mark - Progress Bar

- (void)startSendingMessage;
{
    if (!self.progressBar) {
        self.progressBar = [CHProgressView viewWithFrame:CGRectMake(0, -20, [[UIScreen mainScreen] bounds].size.width, 20)];
        self.progressBar.hidden = YES;
        self.progressBar.backgroundColor = [UIColor clearColor];
        [self.progressBar setProgressColor:kProgressBarColor];
        [self.navigationController.navigationBar addSubview:self.progressBar];
    }
    
    self.progressBar.progress = 0;
    self.progressBar.hidden = NO;
    [self.progressBar setProgress:0.8 animated:YES];
}

- (void)endSendingMessage;
{
    [self.progressBar setProgress:1 animated:YES].then(^{
        self.progressBar.hidden = YES;
    });
}

- (void)otherGroupMessage:(CHMessage *)message;
{
    AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
    [TSMessage showNotificationInViewController:self.navigationController
                                          title:message.group.name
                                       subtitle:message.text
                                          image:nil
                                           type:TSMessageNotificationTypeMessage
                                       duration:TSMessageNotificationDurationAutomatic
                                       callback:^{
                                           //                                           UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
                                           //                                           CHMessageViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"CHMessageViewController"];
                                           //                                           vc.group = message.group;
                                           //                                           vc.groupId = message.groupId;
                                           //
                                           //                                           [((UINavigationController*)root) popViewControllerAnimated:NO];
                                           //                                           [((UINavigationController*)root) pushViewController:vc animated:YES];
                                       }
                                    buttonTitle:nil
                                 buttonCallback:nil
                                     atPosition:TSMessageNotificationPositionNavBarOverlay
                           canBeDismissedByUser:YES];
}

#pragma mark - Navigation

- (void)detailBarButtonTapped:(UIBarButtonItem *)sender;
{
    
    CHMessageDetailTableViewController *dest = [self.navigationController.storyboard
                                                instantiateViewControllerWithIdentifier:@"CHMessageDetailTableViewController"];
    dest.group = self.group;
    [self.navigationController pushViewController:dest animated:YES];
}

#pragma mark - Camera

-(void)loadCamera;
{
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[DBCameraContainerViewController alloc] initWithDelegate:self]];
    [nav setNavigationBarHidden:YES];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)camera:(id)cameraViewController didFinishWithImage:(UIImage *)image withMetadata:(NSDictionary *)metadata;
{
    [self didPasteImage:image];
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissCamera:(id)cameraViewController;
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)canSendMessage;
{
    return self.textView.text.length > 0 || self.media != nil;
}



@end
