//
//  RCTContextMenuOverlayView.mm
//  Pods
//
//  Created by Ananta Ranganathan on 12/10/25.
//

#import "RCTContextMenuOverlayView.h"

@interface RCTContextMenuOverlayView ()

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *snapshotContainer;
@property (nonatomic, strong) UIView *reactionBar;
@property (nonatomic, strong) UIStackView *actionStack;
@property (nonatomic, copy) NSString *messageText;
@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, assign) bool _isUser;

@end

@implementation RCTContextMenuOverlayView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setupBlurView];
        [self setupTapToDismiss];
    }
    return self;
}

#pragma mark - Setup

- (void)setupBlurView
{
    _blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
    _blurView.frame = self.bounds;
    _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_blurView];
}

- (void)setupTapToDismiss
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(handleBackgroundTap:)];
    [self addGestureRecognizer:tap];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer
{
    CGPoint location = [recognizer locationInView:self];
    
    // Only dismiss if tap is outside the snapshot and menus
    if (!CGRectContainsPoint(_snapshotContainer.frame, location) &&
        !CGRectContainsPoint(_reactionBar.frame, location) &&
        !CGRectContainsPoint(_actionStack.frame, location)) {
        [self dismiss];
    }
}

#pragma mark - Show

- (void)showWithBubbleSnapshot:(UIView *)snapshot
                   bubbleFrame:(CGRect)frameInWindow
                   messageText:(NSString *)text
                        isUser:(BOOL)isUser
                favoriteEmojis:(NSArray<NSString *> *)emojis
{
    _messageText = text;
    _originalFrame = frameInWindow;
    self._isUser = isUser; // Store this as a property
    
    // 1. Add snapshot at its original position
    _snapshotContainer = [[UIView alloc] initWithFrame:frameInWindow];
    [_snapshotContainer addSubview:snapshot];
    snapshot.frame = _snapshotContainer.bounds;
    [self addSubview:_snapshotContainer];
    
    // 2. Create reaction bar and action buttons
    [self createReactionBarWithEmojis:emojis isUser:isUser];
    [self createActionButtonsWithIsUser:isUser];
    
    // 3. Calculate final positions
    CGRect targetBubbleFrame = [self calculateTargetFrameForBubble:frameInWindow isUser:isUser];
    CGRect finalReactionFrame = [self reactionBarFrameForBubbleFrame:targetBubbleFrame isUser:isUser];
    CGRect finalActionFrame = [self actionStackFrameForBubbleFrame:targetBubbleFrame isUser:isUser];
    
    // 4. Set initial state - menus start at bubble center, scaled down
    CGPoint bubbleCenter = CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow));
    
    // Size the frames first so we know their dimensions
    _reactionBar.frame = finalReactionFrame;
    _actionStack.frame = finalActionFrame;
    [_reactionBar layoutIfNeeded];
    [_actionStack layoutIfNeeded];
    
    // Now position at bubble center with scale 0
    _reactionBar.center = bubbleCenter;
    _reactionBar.transform = CGAffineTransformMakeScale(0.01, 0.01);
    _reactionBar.alpha = 0.0;
    
    _actionStack.center = bubbleCenter;
    _actionStack.transform = CGAffineTransformMakeScale(0.01, 0.01);
    _actionStack.alpha = 0.0;
    
    // 5. Animate everything
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // Blur in
        self.blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        
        // Move snapshot to target position
        self.snapshotContainer.frame = targetBubbleFrame;
        
    } completion:nil];
    
    // Stagger the menus slightly for a nicer feel
    [UIView animateWithDuration:0.45
                          delay:0.05
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // Reaction bar pops out and moves up
        self.reactionBar.transform = CGAffineTransformIdentity;
        self.reactionBar.frame = finalReactionFrame;
        self.reactionBar.alpha = 1.0;
    } completion:nil];
    
    [UIView animateWithDuration:0.45
                          delay:0.08
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // Action buttons pop out and move down
        self.actionStack.transform = CGAffineTransformIdentity;
        self.actionStack.frame = finalActionFrame;
        self.actionStack.alpha = 1.0;
    } completion:nil];
}

- (CGRect)calculateTargetFrameForBubble:(CGRect)originalFrame isUser:(BOOL)isUser
{
    CGFloat screenHeight = self.bounds.size.height;
    CGFloat screenWidth = self.bounds.size.width;
    
    // We need ~60pt above for reactions, ~100pt below for actions
    CGFloat reactionBarHeight = 50.0;
    CGFloat actionStackHeight = 90.0;
    CGFloat padding = 16.0;
    
    CGFloat totalNeededHeight = originalFrame.size.height + reactionBarHeight + actionStackHeight + padding * 3;
    
    // Center vertically, but ensure room for menus
    CGFloat targetY = (screenHeight - totalNeededHeight) / 2.0 + reactionBarHeight + padding;
    
    // Keep horizontal position similar (respect isUser alignment)
    CGFloat targetX = originalFrame.origin.x;
    
    // Clamp to screen bounds
    targetY = MAX(reactionBarHeight + padding + 50, targetY); // 50pt from top minimum
    targetY = MIN(screenHeight - originalFrame.size.height - actionStackHeight - padding - 50, targetY);
    
    return CGRectMake(targetX, targetY, originalFrame.size.width, originalFrame.size.height);
}

#pragma mark - Reaction Bar

- (void)createReactionBarWithEmojis:(NSArray<NSString *> *)emojis isUser:(BOOL)isUser
{
    _reactionBar = [[UIView alloc] init];
    _reactionBar.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.9];
    _reactionBar.layer.cornerRadius = 25.0;
    _reactionBar.layer.shadowColor = [UIColor blackColor].CGColor;
    _reactionBar.layer.shadowOpacity = 0.15;
    _reactionBar.layer.shadowOffset = CGSizeMake(0, 2);
    _reactionBar.layer.shadowRadius = 8.0;
    _reactionBar.alpha = 0.0;
    
    UIStackView *emojiStack = [[UIStackView alloc] init];
    emojiStack.axis = UILayoutConstraintAxisHorizontal;
    emojiStack.spacing = 4.0;
    emojiStack.alignment = UIStackViewAlignmentCenter;
    emojiStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    for (NSString *emoji in emojis) {
        UIButton *btn = [self createEmojiButton:emoji];
        [emojiStack addArrangedSubview:btn];
    }
    
    // Add "..." button for full picker
    UIButton *moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [moreBtn setTitle:@"•••" forState:UIControlStateNormal];
    moreBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    [moreBtn setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
    [moreBtn addTarget:self action:@selector(handleMoreEmojis) forControlEvents:UIControlEventTouchUpInside];
    [moreBtn.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [moreBtn.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [emojiStack addArrangedSubview:moreBtn];
    
    [_reactionBar addSubview:emojiStack];
    [NSLayoutConstraint activateConstraints:@[
        [emojiStack.leadingAnchor constraintEqualToAnchor:_reactionBar.leadingAnchor constant:8.0],
        [emojiStack.trailingAnchor constraintEqualToAnchor:_reactionBar.trailingAnchor constant:-8.0],
        [emojiStack.topAnchor constraintEqualToAnchor:_reactionBar.topAnchor constant:4.0],
        [emojiStack.bottomAnchor constraintEqualToAnchor:_reactionBar.bottomAnchor constant:-4.0],
    ]];
    
    [self addSubview:_reactionBar];
}

- (UIButton *)createEmojiButton:(NSString *)emoji
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:emoji forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:28];
    [btn addTarget:self action:@selector(handleEmojiTap:) forControlEvents:UIControlEventTouchUpInside];
    [btn.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [btn.heightAnchor constraintEqualToConstant:44.0].active = YES;
    return btn;
}

- (void)handleEmojiTap:(UIButton *)sender
{
    NSString *emoji = sender.currentTitle;
    if (self.onReactionSelect) {
        self.onReactionSelect(emoji);
    }
    [self dismiss];
}

- (void)handleMoreEmojis
{
    if (self.onEmojiPickerOpen) {
        self.onEmojiPickerOpen();
    }
    // Don't dismiss - let JS handle showing picker and then dismissing
}

- (CGRect)reactionBarFrameForBubbleFrame:(CGRect)bubbleFrame isUser:(BOOL)isUser
{
    CGFloat barWidth = 320.0; // 6 emojis + more button
    CGFloat barHeight = 50.0;
    CGFloat padding = 12.0;
    
    CGFloat x;
    if (isUser) {
        // Align to right edge of bubble
        x = CGRectGetMaxX(bubbleFrame) - barWidth;
    } else {
        // Align to left edge of bubble
        x = bubbleFrame.origin.x;
    }
    
    // Clamp to screen
    x = MAX(16, MIN(self.bounds.size.width - barWidth - 16, x));
    
    CGFloat y = bubbleFrame.origin.y - barHeight - padding;
    
    return CGRectMake(x, y, barWidth, barHeight);
}

#pragma mark - Action Buttons

- (void)createActionButtonsWithIsUser:(BOOL)isUser
{
    _actionStack = [[UIStackView alloc] init];
    _actionStack.axis = UILayoutConstraintAxisVertical;
    _actionStack.spacing = 8.0;
    _actionStack.alignment = UIStackViewAlignmentFill;
    
    UIButton *replyBtn = [self createActionButton:@"Reply" icon:@"arrowshape.turn.up.left.fill"];
    [replyBtn addTarget:self action:@selector(handleReply) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *copyBtn = [self createActionButton:@"Copy" icon:@"doc.on.doc.fill"];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    
    [_actionStack addArrangedSubview:replyBtn];
    [_actionStack addArrangedSubview:copyBtn];
    
    [self addSubview:_actionStack];
}

- (UIButton *)createActionButton:(NSString *)title icon:(NSString *)iconName
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    UIImage *icon = [UIImage systemImageNamed:iconName withConfiguration:config];
    
    [btn setImage:icon forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    [btn setTintColor:[UIColor labelColor]];
    
    btn.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.95];
    btn.layer.cornerRadius = 12.0;
  btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  [btn.heightAnchor constraintEqualToConstant:48.0].active = YES;
    
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.12;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6.0;
    
    return btn;
}

- (void)handleReply
{
    if (self.onReply) {
        self.onReply();
    }
    [self dismiss];
}

- (void)handleCopy
{
    [[UIPasteboard generalPasteboard] setString:_messageText];
    if (self.onCopy) {
        self.onCopy(_messageText);
    }
    [self dismiss];
}

- (CGRect)actionStackFrameForBubbleFrame:(CGRect)bubbleFrame isUser:(BOOL)isUser
{
    CGFloat padding = 12.0;
    CGFloat buttonWidth = 140.0;
    
    CGFloat x;
    if (isUser) {
        // Align to right edge of bubble
        x = CGRectGetMaxX(bubbleFrame) - buttonWidth;
    } else {
        // Align to left edge of bubble
        x = bubbleFrame.origin.x;
    }
    
    // Clamp to screen
    x = MAX(16, MIN(self.bounds.size.width - buttonWidth - 16, x));
    
    CGFloat y = CGRectGetMaxY(bubbleFrame) + padding;
    
    // Height for 2 buttons + spacing
    CGFloat height = 2 * 48.0 + 8.0;
    
    return CGRectMake(x, y, buttonWidth, height);
}

#pragma mark - Dismiss

- (void)dismiss
{
    // Calculate where the bubble center will be when it returns
    CGPoint originalCenter = CGPointMake(CGRectGetMidX(_originalFrame), CGRectGetMidY(_originalFrame));
    
    // Animate menus back into the bubble first
    [UIView animateWithDuration:0.25
                          delay:0
         usingSpringWithDamping:0.9
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        // Menus scale down and move toward bubble center
        self.reactionBar.transform = CGAffineTransformMakeScale(0.01, 0.01);
        self.reactionBar.center = originalCenter;
        self.reactionBar.alpha = 0.0;
        
        self.actionStack.transform = CGAffineTransformMakeScale(0.01, 0.01);
        self.actionStack.center = originalCenter;
        self.actionStack.alpha = 0.0;
    } completion:nil];
    
    // Animate snapshot back and blur out
    [UIView animateWithDuration:0.3
                          delay:0.05
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        // Blur out
        self.blurView.effect = nil;
        
        // Move snapshot back to original position
        self.snapshotContainer.frame = self.originalFrame;
        
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (self.onDismiss) {
            self.onDismiss();
        }
    }];
}

@end
