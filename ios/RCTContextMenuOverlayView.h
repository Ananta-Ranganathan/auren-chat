//
//  RCTContextMenuOverlay.h
//  Pods
//
//  Created by Ananta Ranganathan on 12/10/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTContextMenuOverlayView : UIView

@property (nonatomic, copy) void (^onReply)(void);
@property (nonatomic, copy) void (^onCopy)(NSString *text);
@property (nonatomic, copy) void (^onReactionSelect)(NSString *emoji);
@property (nonatomic, copy) void (^onEmojiPickerOpen)(void);
@property (nonatomic, copy) void (^onDismiss)(void);

- (void)showWithBubbleSnapshot:(UIView *)snapshot
                    bubbleFrame:(CGRect)frameInWindow
                    messageText:(NSString *)text
                       isUser:(BOOL)isUser
                 favoriteEmojis:(NSArray<NSString *> *)emojis;

- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
