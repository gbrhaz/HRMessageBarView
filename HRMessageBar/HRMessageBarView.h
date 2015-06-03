//
//  HRMessageBarView.h
//  Huddle
//
//  Created by Harry Richardson on 17/02/2014.
//
//

#import <UIKit/UIKit.h>

extern NSString * const HRMessageBarViewWillShowNotification;
extern NSString * const HRMessageBarViewWillHideNotification;
extern NSString * const HRMessageBarViewDidShowNotification;
extern NSString * const HRMessageBarViewDidHideNotification;
extern NSString * const HRMessageBarViewTappedNotification;

typedef NS_ENUM(NSInteger, HRMessageBarType) {
    HRMessageBarTypeError,
    HRMessageBarTypeNotification, // Not currently implemented
    HRMessageBarTypeSuccess
};

@class HRMessageBarView;

typedef void (^HRMessageBarTapped)(HRMessageBarView*);



@interface HRMessageBarView : UIView

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *titleExplanation;
@property (nonatomic, copy) NSString *detail;

@property (nonatomic, copy) NSString *reuseIdentifier;

@property (nonatomic) HRMessageBarType type;

@property (nonatomic) double duration;
@property (nonatomic, readonly) BOOL showing;

@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIFont *detailFont;
@property (nonatomic, strong) UIColor *titleColour;
@property (nonatomic, strong) UIColor *detailColour;

@property (nonatomic) BOOL encloseTitleInQuotes;

@property (nonatomic, copy) HRMessageBarTapped tapBlock;

+ (instancetype)messageWithReuseIdentifier:(NSString *)identifier;
+ (instancetype)messageWithType:(HRMessageBarType)type reuseIdentifier:(NSString *)identifier;
+ (instancetype)messageWithTitle:(NSString *)title type:(HRMessageBarType)type;
+ (instancetype)messageWithTitle:(NSString *)title type:(HRMessageBarType)type reuseIdentifier:(NSString*)identifier;
+ (instancetype)messageWithTitle:(NSString *)title detail:(NSString *)detail type:(HRMessageBarType)type;
+ (instancetype)messageWithTitle:(NSString *)title detail:(NSString *)detail type:(HRMessageBarType)type reuseIdentifier:(NSString *)reuseIdentifier duration:(double)duration;

+ (void)startQueue;
+ (void)pauseQueue;
+ (void)hideAndReset;

- (void)enqueue; // Call when using the manager queue, rather than the showAnimated method
- (void)showAnimated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;
- (void)startHideTimer;


@end
