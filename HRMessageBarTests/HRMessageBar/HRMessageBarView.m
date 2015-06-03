//
//  HRMessageBarView.m
//  Huddle
//
//  Created by Harry Richardson on 17/02/2014.
//
//

#import "HRMessageBarView.h"

const CGFloat HRMessageBarViewXPadding = 10.0f;
const CGFloat HRMessageBarViewYPadding = 10.0f;
const CGFloat HRMessageBarViewIconSize = 40.0f;
const CGFloat HRMessageBarViewAnimationDuration = 0.5f;
const double HRMessageBarViewDefaultDuration = 5.0f;
const CGFloat HRMessageBarChevronWidth = 40.0f;
const CGFloat HRMessageBarChevronHeight = 16.0f;

NSString * const HRMessageBarViewWillShowNotification = @"HRMessageBarViewWillShowNotification";
NSString * const HRMessageBarViewWillHideNotification = @"HRMessageBarViewWillHideNotification";
NSString * const HRMessageBarViewDidShowNotification = @"HRMessageBarViewDidShowNotification";
NSString * const HRMessageBarViewDidHideNotification = @"HRMessageBarViewDidHideNotification";
NSString * const HRMessageBarViewTappedNotification = @"HRMessageBarViewTappedNotification";

#ifndef SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#endif

#ifndef SYSTEM_VERSION_LESS_THAN
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#endif

#define SCREEN_WIDTH ((([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown) || SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) ? [[UIScreen mainScreen] bounds].size.width : [[UIScreen mainScreen] bounds].size.height)
#define SCREEN_HEIGHT ((([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown) || SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) ) ? [[UIScreen mainScreen] bounds].size.height : [[UIScreen mainScreen] bounds].size.width)

@class HRMessageBarView;

//
//  NSString (HRMessageBar)
//
//  Small category for text sizing
//

@interface NSString (HRMessageBar)

- (CGSize)sizeConstrainedToSize:(CGSize)constrainedSize usingFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)sizeConstrainedToSize:(CGSize)constrainedSize usingFont:(UIFont *)font withOptions:(NSStringDrawingOptions)options lineBreakMode:(NSLineBreakMode)lineBreakMode;

@end


@implementation NSString (HRMessageBar)

- (CGSize)sizeConstrainedToSize:(CGSize)constrainedSize usingFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode {
    return [self sizeConstrainedToSize:constrainedSize
                             usingFont:font
                           withOptions:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin
                         lineBreakMode:lineBreakMode];
}

- (CGSize)sizeConstrainedToSize:(CGSize)constrainedSize usingFont:(UIFont *)font withOptions:(NSStringDrawingOptions)options lineBreakMode:(NSLineBreakMode)lineBreakMode {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = lineBreakMode;
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:self attributes:@{NSFontAttributeName: font, NSParagraphStyleAttributeName: paragraphStyle}];
    CGRect rect = [attributedText boundingRectWithSize:constrainedSize options:options context:nil];
    CGSize textSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
    
    return textSize;
}

@end

//
//  HRMessageBarManager
//
//  A simple manager class that takes care of queuing, pausing,
//  and resetting message bars. Also deals with reuse identifiers.
//


@interface HRMessageBarManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *reusableMessages;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic) BOOL paused;

+ (instancetype)sharedManager;
- (HRMessageBarView*)messageBarViewForReuseIdentifier:(NSString *)reuseIdentifier;
- (void)addMessageBar:(HRMessageBarView *)messageBar forReuseIdentifier:(NSString *)reuseIdentifier;
- (void)removeMessageBar:(HRMessageBarView *)messageBar forReuseIdentifier:(NSString *)reuseIdentifier;

- (void)enqueueMessage:(HRMessageBarView*)message;
- (void)removeFromQueue:(HRMessageBarView*)message showNextMessage:(BOOL)showNext;

- (void)pauseQueue;
- (void)startQueue;
- (void)reset;

@end

@implementation HRMessageBarManager

+ (instancetype)sharedManager {
    static HRMessageBarManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (id)init {
    if (self = [super init]) {
        _reusableMessages = [NSMutableDictionary dictionary];
        _messageQueue = [NSMutableArray array];
    }
    
    return self;
}

- (NSArray *)queue {
    return self.messageQueue;
}

- (HRMessageBarView *)messageBarViewForReuseIdentifier:(NSString *)reuseIdentifier {
    HRMessageBarView *message = self.reusableMessages[reuseIdentifier];
    return message;
}

- (void)addMessageBar:(HRMessageBarView *)messageBar forReuseIdentifier:(NSString *)reuseIdentifier {
    self.reusableMessages[reuseIdentifier] = messageBar;
}

- (void)removeMessageBar:(HRMessageBarView *)messageBar forReuseIdentifier:(NSString *)reuseIdentifier {
    [self.reusableMessages removeObjectForKey:reuseIdentifier];
}

- (void)enqueueMessage:(HRMessageBarView *)message {
    if ([self.messageQueue containsObject:message]) {
        // If it's the first message in the queue, extend the lifetime of the message
        if (message == self.messageQueue[0]) {
            [message startHideTimer];
        }
        return;
    }
    
    [self.messageQueue addObject:message];
    
    // Start it if it's the first one
    if (self.messageQueue.count == 1 && !self.paused) {
        [message showAnimated:YES];
    }
}

- (void)dequeue {
    if (self.paused) {
        return;
    }
    if (self.messageQueue.count > 0) {
        [self.messageQueue[0] showAnimated:YES];
    }
}

- (void)removeFromQueue:(HRMessageBarView *)message showNextMessage:(BOOL)showNext {
    [self.messageQueue removeObject:message];
    if (showNext) {
        [self dequeue];
    }
}

- (void)pauseQueue {
    self.paused = YES;
}

- (void)startQueue {
    self.paused = NO;
    [self dequeue];
}

- (void)reset {
    if (self.messageQueue.count > 0) {
        HRMessageBarView *msg = self.messageQueue[0];
        [self.messageQueue removeAllObjects];
        [msg hideAnimated:NO];
    }
    [self.messageQueue removeAllObjects];
    self.paused = NO;
}

@end


//
//  HRWindow
//
//  The message bars get put into a custom window, outside of the
//  rest of the app as it gets calculated in a different way. This is
//  mainly for iOS 7 which doesn't fix bounds in the same way that iOS 8 now does
//

@interface HRWindow :UIWindow
@end

@implementation HRWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // Check whether the point is inside the notification frame itself; since
    // the window takes up the whole device screen, we don't want to capture
    // all of the taps
    UIViewController *vc = self.rootViewController;
    UIView *notification = [vc.view subviews][0];
    
    CGPoint newPoint = [notification convertPoint:point fromView:self];
    if ([notification pointInside:newPoint withEvent:event]) {
        return YES;
    }
    return NO;
}

@end

//
//  HRMessageBarView
//
//  Customisable message bar that handles text sizing, trimming,
//  and animating.
//

@interface HRMessageBarView()

@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic, strong) HRWindow *notificationWindow;
@property (nonatomic) BOOL dragging;
@property (nonatomic) CGPoint lastTranslation;
@property (nonatomic) BOOL showing;

@end

@implementation HRMessageBarView

+ (instancetype)messageWithReuseIdentifier:(NSString *)identifier {
    return [[HRMessageBarManager sharedManager] messageBarViewForReuseIdentifier:identifier];
}

+ (instancetype)messageWithType:(HRMessageBarType)type reuseIdentifier:(NSString *)identifier {
    return [self messageWithTitle:nil type:type reuseIdentifier:identifier];
}

+ (instancetype)messageWithTitle:(NSString *)title type:(HRMessageBarType)type {
    return [self messageWithTitle:title type:type reuseIdentifier:nil];
}

+ (instancetype)messageWithTitle:(NSString *)title type:(HRMessageBarType)type reuseIdentifier:(NSString*)identifier {
    return [self messageWithTitle:title detail:nil type:type reuseIdentifier:identifier duration:HRMessageBarViewDefaultDuration];
}

+ (instancetype)messageWithTitle:(NSString *)title detail:(NSString *)detail type:(HRMessageBarType)type {
    return [self messageWithTitle:title detail:detail type:type reuseIdentifier:Nil duration:HRMessageBarViewDefaultDuration];
}

+ (instancetype)messageWithTitle:(NSString *)title
                         detail:(NSString *)detail
                           type:(HRMessageBarType)type
                reuseIdentifier:(NSString *)reuseIdentifier
                       duration:(double)duration {
    HRMessageBarView *messageView;
    if (reuseIdentifier) {
        messageView = [[HRMessageBarManager sharedManager] messageBarViewForReuseIdentifier:reuseIdentifier];
    }
    
    if (!messageView) {
        messageView = [[self alloc] init];
        
        messageView.title = title;
        messageView.detail = detail;
        messageView.type = type;
        messageView.duration = duration;
        
        if (reuseIdentifier) {
            [[HRMessageBarManager sharedManager] addMessageBar:messageView forReuseIdentifier:reuseIdentifier];
        }
    }
    
    return messageView;
}

+ (void)startQueue {
    [[HRMessageBarManager sharedManager] startQueue];
}

+ (void)pauseQueue {
    [[HRMessageBarManager sharedManager] pauseQueue];
}

+ (void)hideAndReset {
    [[HRMessageBarManager sharedManager] reset];
}

- (id)init {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.userInteractionEnabled = YES;
        
        _titleFont = [UIFont systemFontOfSize:16];
        _detailFont = [UIFont systemFontOfSize:14];
        _titleColour = [UIColor whiteColor];
        _detailColour = [UIColor whiteColor];
        
        // Swipe up to dismiss
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUpGesture:)];
        swipe.direction = UISwipeGestureRecognizerDirectionUp;
        [self addGestureRecognizer:swipe];
        
        // Tap to "go somewhere"
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
        [self addGestureRecognizer:tap];
        
        CGRect notificationFrame = [[UIScreen mainScreen] bounds];
        HRWindow *notificationWindow = [[HRWindow alloc] initWithFrame:notificationFrame];
        notificationWindow.backgroundColor = [UIColor clearColor];
        notificationWindow.windowLevel = UIWindowLevelStatusBar;
        notificationWindow.rootViewController = [UIViewController new];
        notificationWindow.rootViewController.view.autoresizingMask = UIViewAutoresizingNone;
        self.notificationWindow = notificationWindow;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deviceOrientationDidChangeNotification:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];

        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
        [self addGestureRecognizer:panGesture];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)deviceOrientationDidChangeNotification:(NSNotification *)notification {
    // Change the frame based on orientation
    self.frame = [self calculateFrame];
    [self setNeedsDisplay];
}

#pragma mark - Properties

-(void)setTitle:(NSString *)title {
    _title = title;
    [self setNeedsDisplay];
}

-(void)setDetail:(NSString *)detail {
    _detail = detail;
    [self setNeedsDisplay];
}

- (void)setTitleExplanation:(NSString *)titleExplanation {
    _titleExplanation = titleExplanation;
    [self setNeedsDisplay];
}

#pragma mark - Public

- (void)enqueue {
    [[HRMessageBarManager sharedManager] enqueueMessage:self];
}

- (void)setNotificationWindowFrameFromNotificationFrame:(CGRect)frame {
    // Deal with the notification window sizes
    CGSize notificationSize = frame.size;
    self.notificationWindow.hidden = NO;
    CGFloat yOrigin = 0;
    CGRect containerFrame = CGRectMake(0, yOrigin, SCREEN_WIDTH, frame.size.height);
    
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeLeft) {
            containerFrame = CGRectMake(yOrigin,
                                        0,
                                        notificationSize.height,
                                        notificationSize.width);
        } else if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeRight) {
            containerFrame = CGRectMake(CGRectGetWidth([[UIScreen mainScreen] bounds])-notificationSize.height-yOrigin,
                                        0,
                                        notificationSize.height,
                                        notificationSize.width);
        } else if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown) {
            containerFrame = CGRectMake(0,
                                        CGRectGetHeight([[UIScreen mainScreen] bounds])-notificationSize.height-yOrigin,
                                        notificationSize.width,
                                        notificationSize.height);
        }
    }

    self.notificationWindow.rootViewController.view.frame = containerFrame;
}

- (void)showAnimated:(BOOL)animated {
    if (self.showing) {
        [self startHideTimer];
        return;
    }
    
    if (!self.superview) {
        [self.notificationWindow.rootViewController.view addSubview:self];
    }
    
    __block CGRect frame = [self calculateFrame];
    [self setNotificationWindowFrameFromNotificationFrame:frame];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:HRMessageBarViewWillShowNotification object:self];
    
    self.showing = YES;
    
    CGFloat height = frame.size.height;
    frame.origin.y = -height;
    self.frame = frame;
    
    CGFloat duration = animated ? HRMessageBarViewAnimationDuration : 0.0;
    [UIView animateWithDuration:duration animations:^{
        frame.origin.y = 0;
        self.frame = frame;
    } completion:^(BOOL finished) {
        [self startHideTimer];
        [[NSNotificationCenter defaultCenter] postNotificationName:HRMessageBarViewDidShowNotification object:self];
    }];
}

- (void)hideAnimated:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] postNotificationName:HRMessageBarViewWillHideNotification object:self];
    CGFloat duration = animated ? HRMessageBarViewAnimationDuration : 0.0;
    [UIView animateWithDuration:duration animations:^{
        CGRect frame = self.frame;
        frame.origin.y -= frame.size.height;
        self.frame = frame;
        
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        self.showing = NO;
        [[HRMessageBarManager sharedManager] removeFromQueue:self showNextMessage:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:HRMessageBarViewDidHideNotification object:self];
        self.notificationWindow.hidden = YES;
    }];
}

- (void)startHideTimer {
    [self invalidateHideTimer];
    
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:self.duration target:self selector:@selector(hide) userInfo:nil repeats:NO];
}

- (void)invalidateHideTimer {
    [self.hideTimer invalidate];
    self.hideTimer = nil;
}

#pragma mark - Private

- (void)panGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // The user has just started panning, reset the necessary properties
        self.dragging = YES;
        self.lastTranslation = CGPointMake(0, 0);
    } else if (gesture.state == UIGestureRecognizerStateChanged && self.dragging) {
        // The user is continuing to pan - we want to increase the y-origin, but also cap it so that the notification bar doesn't come anywhere further from the top
        CGRect frame = self.frame;
        frame.origin.y += translation.y - self.lastTranslation.y;
        if (frame.origin.y > 0) {
            frame.origin.y = 0;
        }
        self.frame = frame;
    } else if (gesture.state == UIGestureRecognizerStateEnded && self.dragging) {
        // The user has finished panning - we need to determine whether we should close the notification bar
        // or expand it to its normal size. Look at the velocity and how much the user has translated the notification -
        // if it's over a certain amount, animate to close, or animate to open again.
        self.dragging = NO;
        CGPoint velocity = [gesture velocityInView:self];
        CGFloat magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y)); // for this case will always be ABS(velocity.y)
        BOOL closing = velocity.y < 0 && translation.y < -15.0;
        
        if (closing) {
            CGFloat finish = -self.frame.size.height;
            CGFloat deltaRemaining = finish - self.frame.origin.y;
            CGFloat time = deltaRemaining / magnitude;
            if (time > 1) {
                time = 1;
            }
            
            [UIView animateWithDuration:time animations:^{
                CGRect frame = self.frame;
                frame.origin.y = -frame.size.height;
                self.frame = frame;
            } completion:^(BOOL finished) {
                [self hideAnimated:NO];
            }];
        } else {
            CGFloat deltaRemaining = 0 - self.frame.origin.y;
            CGFloat time = deltaRemaining / magnitude;
            if (time > 0.7) {
                time = 0.7;
            }
            
            [UIView animateWithDuration:time animations:^{
                CGRect frame = self.frame;
                frame.origin.y = 0;
                self.frame = frame;
            } completion:^(BOOL finished) {
                [self startHideTimer];
            }];
            
        }
    }
    
    self.lastTranslation = translation;
    [self startHideTimer];
}

- (void)show {
    [self showAnimated:YES];
}

- (void)hide {
    [self hideAnimated:YES];
}

-(void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Background
    CGContextSaveGState(context);
    {
        [[UIColor colorWithRed:48.0/255.0 green:66.0/255.0 blue:78.0/255.0 alpha:1.0] set];
        CGContextFillRect(context, rect);
    }
    CGContextRestoreGState(context);
    
    CGSize titleSize = [self titleStringSize];
    CGSize detailSize = [self detailStringSize];
    
    CGFloat textHeight = titleSize.height + detailSize.height;
    if (self.detail) {
        textHeight += (HRMessageBarViewYPadding * 0.5);
    }

    CGFloat xOffsetTitle = HRMessageBarViewIconSize + (HRMessageBarViewXPadding * 2);
    CGFloat xOffsetDetail = HRMessageBarViewIconSize + (HRMessageBarViewXPadding * 2);
    CGFloat yOffset = ceil(rect.size.height * 0.5) - ceil(textHeight * 0.5);
    
    // Icon
    CGContextSaveGState(context);
    {
        CGFloat xOffsetIcon = HRMessageBarViewXPadding;
        CGFloat yOffsetIcon = ceil(rect.size.height * 0.5) - ceil(HRMessageBarViewIconSize * 0.5);
        CGRect iconRect = CGRectMake(xOffsetIcon,
                                     yOffsetIcon,
                                     HRMessageBarViewIconSize,
                                     HRMessageBarViewIconSize);
        if (self.type == HRMessageBarTypeError) {
            [[UIImage imageNamed:@"HRMessageBarView.bundle/notifyError"] drawInRect:iconRect];
        } else if (self.type == HRMessageBarTypeNotification) {
            // Not currently implemented
        } else if (self.type == HRMessageBarTypeSuccess) {
            [[UIImage imageNamed:@"HRMessageBarView.bundle/notifySucceed"] drawInRect:iconRect];
        }
    }
    CGContextRestoreGState(context);
    
    // Chevron
    CGContextSaveGState(context);
    {
        CGFloat xOffsetChevron = ceil(rect.size.width * 0.5) - ceil(HRMessageBarChevronWidth * 0.5);
        CGFloat yOffsetChevron = rect.size.height - HRMessageBarChevronHeight - 4;
        [[UIImage imageNamed:@"HRMessageBarView.bundle/chevUp"] drawInRect:CGRectMake(xOffsetChevron, yOffsetChevron, HRMessageBarChevronWidth, HRMessageBarChevronHeight)];
    }
    CGContextRestoreGState(context);
    
    // Bottom border
    CGContextSaveGState(context);
    {
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.2 alpha:0.9].CGColor);
        CGContextFillRect(context, CGRectMake(0, rect.size.height-0.5, rect.size.width, 0.5f));
    }
    CGContextRestoreGState(context);
    
    // Title
    NSString *newTitle = [NSString stringWithFormat:@"%@%@", [self extraTitleCharacters], self.title];
    CGRect titleRect = CGRectMake(xOffsetTitle, yOffset, titleSize.width, titleSize.height);
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    [newTitle drawInRect:titleRect
          withAttributes:@{NSFontAttributeName: self.titleFont, NSForegroundColorAttributeName: self.titleColour, NSParagraphStyleAttributeName: paragraphStyle}];
    
    // Title explanation
    if (self.titleExplanation) {
        CGSize titleExplanationSize = [self titleExplanationStringSize];
        xOffsetTitle += titleSize.width;
        NSString *newTitleExplanation = [NSString stringWithFormat:@"%@%@", [self extraTitleExplanationCharacters], self.titleExplanation];
        [newTitleExplanation drawInRect:CGRectMake(xOffsetTitle, yOffset, titleExplanationSize.width, titleExplanationSize.height)
                         withAttributes:@{NSFontAttributeName: self.titleFont, NSForegroundColorAttributeName: self.titleColour, NSParagraphStyleAttributeName: paragraphStyle}];
    }
    
    yOffset += titleSize.height + (HRMessageBarViewYPadding * 0.5);
    
    // Detail
    NSMutableParagraphStyle *detailParagraphStyle = [NSMutableParagraphStyle new];
    detailParagraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    detailParagraphStyle.alignment = NSTextAlignmentLeft;
    [self.detail drawInRect:CGRectMake(xOffsetDetail, yOffset, detailSize.width, detailSize.height)
             withAttributes:@{NSFontAttributeName: self.detailFont, NSForegroundColorAttributeName: self.detailColour, NSParagraphStyleAttributeName: detailParagraphStyle}];
}

#pragma mark - Calculate Sizes

- (CGRect)calculateFrame {
    CGFloat titleHeight = [self titleStringSize].height;
    CGFloat detailHeight = [self detailStringSize].height;
    
    CGFloat height = titleHeight + detailHeight + (HRMessageBarViewYPadding * 3);
    if (!self.detail) {
        height -= HRMessageBarViewYPadding;
        height += 20.0;
    }
    
    // Display below the navigation bar
    return CGRectMake(0, 0, SCREEN_WIDTH, height);
}

- (CGFloat)availableTextWidth {
    return SCREEN_WIDTH - (HRMessageBarViewXPadding * 3) - HRMessageBarViewIconSize;
}

- (CGFloat)availableTitleWidth {
    return [self availableTextWidth] - [self titleExplanationStringSize].width;
}

- (CGFloat)availableTitleExplanationWidth {
    return [self availableTextWidth];
}

- (CGSize)titleStringSize {
    CGSize titleSize = [self.title sizeConstrainedToSize:CGSizeMake([self availableTitleWidth], CGFLOAT_MAX)
                                               usingFont:self.titleFont
                                           lineBreakMode:NSLineBreakByTruncatingTail];
    CGSize extraCharsSize = [[self extraTitleCharacters] sizeConstrainedToSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                                     usingFont:self.titleFont
                                                                 lineBreakMode:NSLineBreakByWordWrapping];
    
    titleSize.width += extraCharsSize.width;
    return titleSize;
}

- (CGSize)titleExplanationStringSize {
    CGSize titleSize = [self.titleExplanation sizeConstrainedToSize:CGSizeMake([self availableTitleExplanationWidth], CGFLOAT_MAX)
                                                          usingFont:self.titleFont
                                                      lineBreakMode:NSLineBreakByWordWrapping];
    CGSize extraCharsSize = [[self extraTitleExplanationCharacters] sizeConstrainedToSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                                                usingFont:self.titleFont
                                                                            lineBreakMode:NSLineBreakByWordWrapping];
    
    titleSize.width += extraCharsSize.width;
    return titleSize;
}

- (CGSize)detailStringSize {
    CGSize size = [self.detail sizeConstrainedToSize:CGSizeMake([self availableTextWidth], CGFLOAT_MAX)
                                           usingFont:self.detailFont
                                       lineBreakMode:NSLineBreakByTruncatingTail];
    return size;
}

- (NSString *)extraTitleCharacters {
    return self.encloseTitleInQuotes ? @"‘" : @"";
}

- (NSString *)extraTitleExplanationCharacters {
    return self.encloseTitleInQuotes ? @"’ " : @" ";
}

#pragma mark - Gestures

- (void)swipeUpGesture:(id)sender {
    [self invalidateHideTimer];
    [self hide];
}

- (void)tapGesture:(id)sender {
    BOOL hasTapBlock = self.tapBlock != nil;
    if (hasTapBlock) {
        [[NSNotificationCenter defaultCenter] postNotificationName:HRMessageBarViewTappedNotification object:nil];
        self.tapBlock(self);
    }
    // Hide immediately if there's a tap block, otherwise hide animatedly
    [self hideAnimated:!hasTapBlock];

}

@end
