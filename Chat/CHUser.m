//
//  Chat
//
//  Created by Ethan Mick on 8/12/14.
//
//
#import "CHUser.h"
#import "CHGroup.h"
#import "Promise.h"
#import "CHMessage.h"
#import "Mantle.h"
#import "CHNetworkManager.h"
#import "CHSocketManager.h"
#import "UIImage+ColorArt.h"
#import "CHNetworkManager.h"
#import "CHBackgroundContext.h"

#define ONE_HOUR 60*60

NSString *const kCHUserDoNotDisturbKey = @"doNotDisturb";

@interface CHUser ()

@property (nonatomic, retain) UIColor * avatarColor;
@property (nonatomic, retain) NSDate * lastAvatarFetch;

@end


@implementation CHUser

@synthesize avatarColor = _avatarColor;
@synthesize password = _password;
@synthesize lastAvatarFetch = _lastAvatarFetch;

static CHUser *_currentUser = nil;
+ (instancetype)currentUser;
{
    if (!_currentUser) {
        _currentUser = [CHUser MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"currentUser = YES"]];
        if (_currentUser.sessionToken) {
            [[CHNetworkManager sharedManager] setSessionToken:_currentUser.sessionToken];
        }
    }
    return _currentUser;
}

+ (instancetype)userWithUsername:(NSString *)username password:(NSString *)password;
{
    CHUser *user = [CHUser MR_createEntity];
    user.username = username;
    user.password = password;
    return user;
}

- (PMKPromise *)login;
{
    return [[CHNetworkManager sharedManager] loginWithUser:self].then(^(){
        self.currentUserValue = YES;
        _currentUser = self;
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        return [self profile].then(^{
            return self;
        });
    });
}

- (PMKPromise *)profile;
{
    return [[CHNetworkManager sharedManager] currentUserProfile];
}

- (PMKPromise *)registr;
{
    return [[CHNetworkManager sharedManager] registerWithUser:self].then(^{
        return [self login];
    });
}

- (BOOL)isLoggedIn;
{
    return self.sessionToken != nil;
}

- (PMKPromise *)leaveGroupAtIndex:(NSUInteger)index;
{
    CHGroup *group = self.groups[index];
    [self removeGroupsObject:group];
    [self addPastGroupsObject:group];
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreWithCompletion:^(BOOL success, NSError *error) {
        DLog(@"Leave Ground Background Save Completed: Error? %@", error);
    }];
    return [[CHNetworkManager sharedManager] leaveGroup:group.chID];
}

- (NSOrderedSet *)groups;
{
    NSMutableOrderedSet *unsortedGroups = [self primitiveGroups];
    [unsortedGroups sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastMessage.sent" ascending:NO]]];
    return unsortedGroups;
}

#pragma mark - Remote Getters

- (PMKPromise *)remoteGroups;
{
    return [[CHNetworkManager sharedManager] currentUserGroups];
}

- (PMKPromise *)avatar;
{
    if (self.privateAvatar || (self.lastAvatarFetch && ABS([self.lastAvatarFetch timeIntervalSinceNow]) < ONE_HOUR)) {
        return [PMKPromise new:^(PMKPromiseFulfiller fulfiller, PMKPromiseRejecter rejecter) {
            if (!self.privateAvatar) {
                rejecter(nil);
            } else {
                fulfiller(PMKManifold(self, self.privateAvatar));
            }
        }];
    }
    
    return [[CHNetworkManager sharedManager] avatarForUser:self].then(^(UIImage *avatar){
        self.lastAvatarFetch = [NSDate date];
        self.privateAvatar = avatar;
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreWithCompletion:^(BOOL success, NSError *error) {
            DLog(@"Background Save Avatar Completed: Error? %@", error);
        }];
        return PMKManifold(self, self.privateAvatar);
    }).catch(^(NSError *error){
        self.lastAvatarFetch = [NSDate date];
        return error;
    });
}

- (PMKPromise *)avatar:(UIImage *)image;
{
    self.privateAvatar = image;
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    return [[CHNetworkManager sharedManager] newAvatar:image forUser:self].then(^{
    });
}

- (PMKPromise *)sendMessage:(CHMessage *)message toGroup:(CHGroup *)group;
{
    if (message.hasMediaValue) {
        return [[CHNetworkManager sharedManager] postMediaMessageWithImage:message.theMediaSent groupId:group.chID message:message.text]
            .then(^(NSDictionary *response){
                message.chID = response[@"_id"];
                [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                return message;
        });
        
    } else {
        return [PMKPromise new:^(PMKPromiseFulfiller fulfiller, PMKPromiseRejecter rejecter) {
            [[CHSocketManager sharedManager] sendMessageWithData:@{@"from": self.chID, @"text" : message.text, @"group": group.chID}
                                                  acknowledgement:^(id argsData) {
                                                      DLog(@"Args: %@", argsData);
                                                      message.chID = argsData[@"_id"];
                                                      [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                                                      fulfiller(message);
                                                  }];
        }];
    }
}

- (PMKPromise *)logout:(BOOL)all;
{
    return [[CHNetworkManager sharedManager] logout:all].then(^{
        _currentUser = nil;
    });
}

- (PMKPromise *)promiseDoNotDisturb:(BOOL)value;
{
    return [[CHNetworkManager sharedManager] updateUserSettings:@{kCHUserDoNotDisturbKey: @(value)}].then(^{
        DLog(@"Value: %d", value);
        [self setDoNotDisturbValue:value];
    });
}

- (void)setAvatar:(UIImage *)avatar;
{
    self.privateAvatar = avatar;
}

- (UIColor *)color;
{
    if (self.avatarColor) {
        return self.avatarColor;
    } else if (self.privateAvatar) {
        SLColorArt *colorArt = [self.privateAvatar colorArt];
        self.avatarColor = colorArt.primaryColor;
        return self.avatarColor;
    } else {
        return [UIColor blackColor];
    }
}

- (void)createdFromMantle;
{
    [super createdFromMantle];

    NSManagedObjectContext *context = [NSThread isMainThread] ? [NSManagedObjectContext MR_defaultContext] : CHBackgroundContext.backgroundContext.context;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.authorId == %@ AND SELF.author == nil", self.chID];
    NSArray *messages = [CHMessage MR_findAllWithPredicate:predicate inContext:context];
    for (CHMessage *message in messages) {
        message.author = self;
    }
}

#pragma mark - Mantle / Core Data

- (void)removeGroupsObject:(CHGroup *)value_;
{
    NSMutableOrderedSet *tmpOrderedSet = [NSMutableOrderedSet orderedSetWithOrderedSet:[self mutableOrderedSetValueForKey:@"groups"]];
    NSUInteger idx = [tmpOrderedSet indexOfObject:value_];
    if (idx != NSNotFound) {
        NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:idx];
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"groups"];
        [tmpOrderedSet removeObject:value_];
        [self setPrimitiveValue:tmpOrderedSet forKey:@"groups"];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"groups"];
    }
}

- (void)addPastGroupsObject:(CHGroup*)value_;
{
    NSMutableOrderedSet *tmpOrderedSet = [NSMutableOrderedSet orderedSetWithOrderedSet:[self mutableOrderedSetValueForKey:@"pastGroups"]];
    NSUInteger idx = [tmpOrderedSet count];
    NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:idx];
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"pastGroups"];
    [tmpOrderedSet addObject:value_];
    [self setPrimitiveValue:tmpOrderedSet forKey:@"pastGroups"];
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"pastGroups"];
}

- (void)addGroupsObject:(CHGroup *)value_
{
    NSMutableOrderedSet *tmpOrderedSet = [NSMutableOrderedSet orderedSetWithOrderedSet:[self mutableOrderedSetValueForKey:@"pastGroups"]];
    NSUInteger idx = [tmpOrderedSet count];
    NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:idx];
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"groups"];
    [tmpOrderedSet addObject:value_];
    [self setPrimitiveValue:tmpOrderedSet forKey:@"groups"];
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"groups"];
}



@end
