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
@property (nonatomic, assign) BOOL isUser;
@property (nonatomic, assign) BOOL isDarkMode;

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
                    isDarkMode:(BOOL)isDarkMode
{
    _messageText = text;
    _originalFrame = frameInWindow;
    _isUser = isUser;
    _isDarkMode = isDarkMode;
  
    if (_onToggleOriginalBubble) _onToggleOriginalBubble(YES);
    
    // 1. Add snapshot at its original position
    _snapshotContainer = [[UIView alloc] initWithFrame:frameInWindow];
    [_snapshotContainer addSubview:snapshot];
    snapshot.frame = _snapshotContainer.bounds;
    [self addSubview:_snapshotContainer];
    
    // 2. Create reaction bar and action buttons
    if (!isUser) {
        [self createReactionBarWithEmojis:emojis isUser:isUser];
    }
    [self createActionButtonsWithIsUser:isUser];
    
    // 3. Calculate final positions
    CGRect targetBubbleFrame = [self calculateTargetFrameForBubble:frameInWindow isUser:isUser];
    CGRect finalReactionFrame = [self reactionBarFrameForBubbleFrame:targetBubbleFrame isUser:isUser];
    CGRect finalActionFrame = [self actionStackFrameForBubbleFrame:targetBubbleFrame isUser:isUser];
    
    
    // Size the frames first so we know their dimensions
    _reactionBar.frame = finalReactionFrame;
    _actionStack.frame = finalActionFrame;
    [_reactionBar layoutIfNeeded];
    [_actionStack layoutIfNeeded];
  // Reaction bar: anchor at bottom center (it expands upward from below the bubble)
  _reactionBar.layer.anchorPoint = CGPointMake(0.5, 1.0);
  // Action stack: anchor at top center (it expands downward from above the bubble)
  _actionStack.layer.anchorPoint = CGPointMake(0.5, 0.0);
    
  // Position at final X but at bubble edge Y, scaled to zero height
  _reactionBar.frame = CGRectMake(finalReactionFrame.origin.x,
                                   CGRectGetMinY(frameInWindow),  // Top edge of bubble
                                   finalReactionFrame.size.width,
                                   finalReactionFrame.size.height);
  _reactionBar.transform = CGAffineTransformMakeScale(1.0, 0.01);  // Only scale Y

  _actionStack.frame = CGRectMake(finalActionFrame.origin.x,
                                   CGRectGetMaxY(frameInWindow),  // Bottom edge of bubble
                                   finalActionFrame.size.width,
                                   finalActionFrame.size.height);
  _actionStack.transform = CGAffineTransformMakeScale(1.0, 0.01);  // Only scale Y
    
    // 5. Animate everything
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // Blur in
        self.blurView.effect = [UIBlurEffect effectWithStyle:isDarkMode ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight];
        
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
    
    CGFloat reactionBarHeight = 50.0;
    CGFloat actionStackHeight = 90.0;
    CGFloat padding = 12.0;
    CGFloat safeTop = 50.0;
    CGFloat safeBottom = 50.0;
    
    // Start with original position - only move if necessary
    CGFloat targetY = originalFrame.origin.y;
    CGFloat targetX = originalFrame.origin.x;
    
    // Check if reaction bar fits above
    CGFloat spaceNeededAbove = reactionBarHeight + padding;
    if (targetY < safeTop + spaceNeededAbove) {
        targetY = safeTop + spaceNeededAbove;
    }
    
    // Check if action buttons fit below
    CGFloat bubbleBottom = targetY + originalFrame.size.height;
    CGFloat spaceNeededBelow = actionStackHeight + padding;
    if (bubbleBottom + spaceNeededBelow > screenHeight - safeBottom) {
        targetY = screenHeight - safeBottom - spaceNeededBelow - originalFrame.size.height;
    }
    
    // Final clamp
    targetY = MAX(safeTop + spaceNeededAbove, targetY);
    
    return CGRectMake(targetX, targetY, originalFrame.size.width, originalFrame.size.height);
}

#pragma mark - Reaction Bar

- (void)createReactionBarWithEmojis:(NSArray<NSString *> *)emojis isUser:(BOOL)isUser
{
    _reactionBar = [[UIView alloc] init];
  if (@available(iOS 26.0, *)) {
      _reactionBar.backgroundColor = [UIColor clearColor];
      UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:[[UIGlassEffect alloc] init]];
      glassView.frame = _reactionBar.bounds;
      glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      glassView.layer.cornerRadius = 25.0;
      glassView.clipsToBounds = YES;
      [_reactionBar insertSubview:glassView atIndex:0];
  } else {
      _reactionBar.backgroundColor = [(_isDarkMode ? [UIColor colorWithWhite:0.15 alpha:1.0] : [UIColor whiteColor]) colorWithAlphaComponent:0.95];
  }
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
    UIView *menuCard;
    UIView *contentContainer;
    
  if (@available(iOS 26.0, *)) {
      menuCard = [[UIView alloc] init];
      menuCard.backgroundColor = [UIColor clearColor];
      
      UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:[[UIGlassEffect alloc] init]];
      glassView.frame = menuCard.bounds;
      glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      glassView.layer.cornerRadius = 14.0;
      glassView.clipsToBounds = YES;
      [menuCard addSubview:glassView];
      
      contentContainer = menuCard;  // Add buttons directly to menuCard, on top of glass
  } else {
      menuCard = [[UIView alloc] init];
      menuCard.backgroundColor = _isDarkMode ? [UIColor colorWithWhite:0.2 alpha:1.0] : [UIColor whiteColor];
      menuCard.layer.cornerRadius = 14.0;
      menuCard.layer.shadowColor = [UIColor blackColor].CGColor;
      menuCard.layer.shadowOpacity = 0.15;
      menuCard.layer.shadowOffset = CGSizeMake(0, 2);
      menuCard.layer.shadowRadius = 8.0;
      contentContainer = menuCard;
  }
    menuCard.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Reply row
    UIButton *replyBtn = [self createMenuRowButton:@"Reply" icon:@"arrowshape.turn.up.left"];
    [replyBtn addTarget:self action:@selector(handleReply) forControlEvents:UIControlEventTouchUpInside];
    
    // Separator
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = _isDarkMode ? [UIColor colorWithWhite:0.35 alpha:1.0] : [UIColor colorWithWhite:0.85 alpha:1.0];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Copy row
    UIButton *copyBtn = [self createMenuRowButton:@"Copy" icon:@"doc.on.doc"];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    
    [contentContainer addSubview:replyBtn];
    [contentContainer addSubview:separator];
    [contentContainer addSubview:copyBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [replyBtn.topAnchor constraintEqualToAnchor:contentContainer.topAnchor],
        [replyBtn.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
        [replyBtn.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor],
        [replyBtn.heightAnchor constraintEqualToConstant:44.0],
        
        [separator.topAnchor constraintEqualToAnchor:replyBtn.bottomAnchor],
        [separator.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:0.5],
        
        [copyBtn.topAnchor constraintEqualToAnchor:separator.bottomAnchor],
        [copyBtn.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
        [copyBtn.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor],
        [copyBtn.heightAnchor constraintEqualToConstant:44.0],
        [copyBtn.bottomAnchor constraintEqualToAnchor:contentContainer.bottomAnchor],
    ]];
    
    // Wrap in stack for existing positioning logic
    _actionStack = [[UIStackView alloc] init];
    _actionStack.translatesAutoresizingMaskIntoConstraints = YES;
    [_actionStack addArrangedSubview:menuCard];
    
    [self addSubview:_actionStack];
}

- (UIButton *)createMenuRowButton:(NSString *)title icon:(NSString *)iconName
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIColor *textColor = _isDarkMode ? [UIColor whiteColor] : [UIColor blackColor];
    [btn setTintColor:textColor];
    
    // Create a configuration for proper layout
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.title = title;
    config.baseForegroundColor = textColor;
    
    UIImageSymbolConfiguration *imgConfig = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
    config.image = [UIImage systemImageNamed:iconName withConfiguration:imgConfig];
    
    // Title on left, image on right, with space between
    config.imagePlacement = NSDirectionalRectEdgeTrailing;
    config.imagePadding = 0;  // Space between title and image
    config.contentInsets = NSDirectionalEdgeInsetsMake(0, 16, 0, 16);
    
    btn.configuration = config;
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    
    // This makes the title left-align and icon right-align
    btn.configurationUpdateHandler = ^(UIButton *button) {
        UIButtonConfiguration *updatedConfig = button.configuration;
        updatedConfig.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
        button.configuration = updatedConfig;
    };
    
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
    CGFloat menuWidth = 150.0;  // UIMenu-like width
    CGFloat menuHeight = 88.5;  // 2 rows × 44 + separator
    
    CGFloat x;
    if (isUser) {
        x = CGRectGetMaxX(bubbleFrame) - menuWidth;
    } else {
        x = bubbleFrame.origin.x;
    }
    
    x = MAX(16, MIN(self.bounds.size.width - menuWidth - 16, x));
    CGFloat y = CGRectGetMaxY(bubbleFrame) + padding;
    
    return CGRectMake(x, y, menuWidth, menuHeight);
}
#pragma mark - Dismiss

- (void)dismiss
{
    // Animate menus back into the bubble first
    [UIView animateWithDuration:0.25
                          delay:0
         usingSpringWithDamping:0.9
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        // Menus scale down vertically only (anchor points already set)
        self.reactionBar.transform = CGAffineTransformMakeScale(1.0, 0.01);
        self.reactionBar.alpha = 0.0;
        
        self.actionStack.transform = CGAffineTransformMakeScale(1.0, 0.01);
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
      if (self.onToggleOriginalBubble) self.onToggleOriginalBubble(NO);
      [self removeFromSuperview];
      if (self.onDismiss) {
          self.onDismiss();
      }
    }]; 
}

@end
