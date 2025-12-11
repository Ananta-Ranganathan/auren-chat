//
//  RCTChatMessageCell.h
//  AurenChatView
//
//  Created by Ananta Ranganathan on 12/2/25.
//

#ifndef RCTChatMessageCell_h
#define RCTChatMessageCell_h

#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTChatMessageCell : UICollectionViewCell

@property(nonatomic, strong) UIView *bubbleView;
@property(nonatomic, strong) UILabel *label;
@property(nonatomic, strong) NSLayoutConstraint *leadingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) UIImageView *readReceiptImageView;
@property (nonatomic, strong) NSLayoutConstraint *labelTrailingConstraint;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UIStackView *imageStackView;
@property (nonatomic, copy) void (^onImageTapped)(NSInteger imageIndex, CGRect frameInWindow);
@property (nonatomic, strong) NSLayoutConstraint *minWidthConstraint;
@property (nonatomic, strong) UIView *reactionContainer;
@property (nonatomic, strong) UILabel *reactionLabel;
@property (nonatomic, strong) NSLayoutConstraint *reactionLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *reactionTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *reactionTopConstraint;
@property (nonatomic, copy) void (^onLongPress)(UIView *bubbleSnapshot, CGRect frameInWindow, NSString *text, BOOL isUser);


- (void)configureWithText:(NSString *)text isUser:(BOOL)isUser sameAsPrevious:(BOOL)sameAsPrevious readByCharacterAt:(double)readByCharacterAt gradientStart:(UIColor*)gradientStart gradientEnd:(UIColor*)gradientEnd reaction:(NSString *)reaction themeColor:(UIColor *)themeColor;
- (void)configureWithImage:(NSDictionary * _Nullable)image;
- (void)updateReadReceiptWithReadByCharacterAt:(double)readByCharacterAt
                                        isUser:(BOOL)isUser;

@end

NS_ASSUME_NONNULL_END

#endif // !RCTChatMessageCell_h
