//  RCTTypingIndicatorCell.h
//  AurenChatView
//
//  Created by Ananta Ranganathan on 12/2/25.
//

#ifndef RCTTypingIndicatorCell_h
#define RCTTypingIndicatorCell_h

#import <UIKit/UIKit.h>

@interface RCTTypingIndicatorCell : UICollectionViewCell

@property (nonatomic, strong) UIView *bubbleView;

- (void)configureWithIsUser:(BOOL)isUser gradientStart:(UIColor *)gradientStart gradientEnd:(UIColor *)gradientEnd;
- (void)startAnimating;
- (void)stopAnimating;

@end

#endif /* RCTTypingIndicatorCell_h */
