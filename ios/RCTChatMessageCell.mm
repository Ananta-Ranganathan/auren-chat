//
//  RCTMessageCell.mm
//  AurenChatView
//
//  Created by Ananta Ranganathan on 12/2/25.
//

#import <Foundation/Foundation.h>

#import "RCTChatMessageCell.h"

#import <react/renderer/components/AurenChatViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/AurenChatViewSpec/EventEmitters.h>
#import <react/renderer/components/AurenChatViewSpec/Props.h>
#import <react/renderer/components/AurenChatViewSpec/RCTComponentViewHelpers.h>

@interface RCTChatMessageCell ()
@property (nonatomic, strong) NSLayoutConstraint *labelTopToBubbleConstraint;
@property (nonatomic, strong) NSLayoutConstraint *labelTopToImageConstraint;
@end

@implementation RCTChatMessageCell {
  BOOL _isUser;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    _bubbleView = [UIView new];
    _bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    _bubbleView.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0];
    _bubbleView.layer.cornerRadius = 18.0;
    _bubbleView.layer.masksToBounds = YES;

    _label = [UILabel new];
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    _label.textColor = [UIColor whiteColor];
    _label.numberOfLines = 0;
    _label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

    // Make bubble prefer to be as small as its contents allow
    [_bubbleView setContentHuggingPriority:UILayoutPriorityRequired
                                   forAxis:UILayoutConstraintAxisHorizontal];
    [_bubbleView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                 forAxis:UILayoutConstraintAxisHorizontal];

    // (optional, but usually good)
    [_label setContentHuggingPriority:UILayoutPriorityRequired
                               forAxis:UILayoutConstraintAxisHorizontal];
    [_label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisHorizontal];
    _maxWidthConstraint = [_bubbleView.widthAnchor constraintLessThanOrEqualToConstant:1000];
    _maxWidthConstraint.active = YES;
    _minWidthConstraint = [_bubbleView.widthAnchor constraintGreaterThanOrEqualToConstant:200.0];
    _minWidthConstraint.active = NO;
    _imageStackView = [[UIStackView alloc] init];
    _imageStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageStackView.axis = UILayoutConstraintAxisVertical;
    _imageStackView.spacing = 4.0;
    _imageStackView.alignment = UIStackViewAlignmentFill;

    [_bubbleView addSubview:_label];
    [_bubbleView addSubview:_imageStackView];
    [self.contentView addSubview:_bubbleView];

    const CGFloat bubbleVertical = 4.0;
    const CGFloat bubbleHorizontal = 12.0;
    const CGFloat labelPaddingVertical = 8.0;
    const CGFloat labelPaddingHorizontal = 12.0;

    _leadingConstraint = [_bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:bubbleHorizontal];
    _trailingConstraint = [_bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-bubbleHorizontal];
    _topConstraint = [_bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0];

    [NSLayoutConstraint activateConstraints:@[
      _topConstraint,
      [_bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-bubbleVertical],
      [_imageStackView.topAnchor constraintEqualToAnchor:_bubbleView.topAnchor],
      [_imageStackView.leadingAnchor constraintEqualToAnchor:_bubbleView.leadingAnchor],
      [_imageStackView.trailingAnchor constraintEqualToAnchor:_bubbleView.trailingAnchor],
      [_label.bottomAnchor constraintEqualToAnchor:_bubbleView.bottomAnchor constant:-labelPaddingVertical],
      [_label.leadingAnchor constraintEqualToAnchor:_bubbleView.leadingAnchor constant:labelPaddingHorizontal],
    ]];
    self.labelTopToBubbleConstraint = [_label.topAnchor constraintEqualToAnchor:_bubbleView.topAnchor constant:labelPaddingVertical];
    self.labelTopToBubbleConstraint.active = YES;
    self.labelTopToImageConstraint = [_label.topAnchor constraintEqualToAnchor:_imageStackView.bottomAnchor constant:labelPaddingVertical];
    _labelTrailingConstraint = [_label.trailingAnchor constraintEqualToAnchor:_bubbleView.trailingAnchor constant:-labelPaddingHorizontal];
    _labelTrailingConstraint.active = YES;
    
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.cornerRadius = 18.0;
    [_bubbleView.layer insertSublayer:self.gradientLayer atIndex:0];
    
    _readReceiptImageView = [UIImageView new];
    _readReceiptImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _readReceiptImageView.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    _readReceiptImageView.contentMode = UIViewContentModeScaleAspectFit;
    [_bubbleView addSubview:_readReceiptImageView];

    [NSLayoutConstraint activateConstraints:@[
      [_readReceiptImageView.trailingAnchor constraintEqualToAnchor:_bubbleView.trailingAnchor constant:-8.0],
      [_readReceiptImageView.bottomAnchor constraintEqualToAnchor:_bubbleView.bottomAnchor constant:-10.0],
      [_readReceiptImageView.widthAnchor constraintEqualToConstant:14.0],
      [_readReceiptImageView.heightAnchor constraintEqualToConstant:14.0],
    ]];

    _reactionContainer = [UIView new];
    _reactionContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _reactionContainer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    _reactionContainer.layer.cornerRadius = 12.0;
    _reactionContainer.layer.masksToBounds = NO;
    _reactionContainer.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
    _reactionContainer.layer.shadowOpacity = 1.0;
    _reactionContainer.layer.shadowOffset = CGSizeMake(0, 1);
    _reactionContainer.layer.shadowRadius = 4.0;

    _reactionLabel = [UILabel new];
    _reactionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _reactionLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _reactionLabel.textColor = [UIColor blackColor];

    [_reactionContainer addSubview:_reactionLabel];
    [NSLayoutConstraint activateConstraints:@[
      [_reactionLabel.topAnchor constraintEqualToAnchor:_reactionContainer.topAnchor constant:4.0],
      [_reactionLabel.bottomAnchor constraintEqualToAnchor:_reactionContainer.bottomAnchor constant:-4.0],
      [_reactionLabel.leadingAnchor constraintEqualToAnchor:_reactionContainer.leadingAnchor constant:4.0],
      [_reactionLabel.trailingAnchor constraintEqualToAnchor:_reactionContainer.trailingAnchor constant:-4.0],
    ]];

    [self.contentView addSubview:_reactionContainer];
    _reactionTopConstraint = [_reactionContainer.topAnchor constraintEqualToAnchor:_bubbleView.topAnchor constant:-6.0];
    _reactionLeadingConstraint = [_reactionContainer.leadingAnchor constraintEqualToAnchor:_bubbleView.leadingAnchor constant:-6.0];
    _reactionTrailingConstraint = [_reactionContainer.trailingAnchor constraintEqualToAnchor:_bubbleView.trailingAnchor constant:6.0];
    [NSLayoutConstraint activateConstraints:@[
      _reactionTopConstraint,
    ]];
    NSLayoutConstraint *reactionHeight = [_reactionContainer.heightAnchor constraintGreaterThanOrEqualToConstant:24.0];
    reactionHeight.active = YES;
    NSLayoutConstraint *reactionWidth = [_reactionContainer.widthAnchor constraintGreaterThanOrEqualToAnchor:_reactionContainer.heightAnchor];
    reactionWidth.active = YES;
    _reactionLeadingConstraint.active = YES;
    _reactionTrailingConstraint.active = NO;

    _reactionContainer.hidden = YES;
    
    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.2;
    [_bubbleView addGestureRecognizer:longPress];
  }
  return self;
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:
    (UICollectionViewLayoutAttributes *)layoutAttributes
{
  return layoutAttributes;
}

- (void)layoutSubviews
{
  [super layoutSubviews];

  CGFloat contentWidth = self.contentView.bounds.size.width;
  CGFloat maxBubbleWidth = contentWidth * 0.75;
  CGFloat labelPaddingHorizontal = 12.0;

  self.label.preferredMaxLayoutWidth = maxBubbleWidth - 2 * labelPaddingHorizontal;
  
  // Only update gradient frame if bounds actually changed
  if (!CGRectEqualToRect(self.gradientLayer.frame, _bubbleView.bounds)) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.gradientLayer.frame = _bubbleView.bounds;
    [CATransaction commit];
  }
}

- (void)configureWithText:(NSString *)text
                   isUser:(BOOL)isUser
           sameAsPrevious:(BOOL)sameAsPrevious
       readByCharacterAt:(double)readByCharacterAt
            gradientStart:(UIColor *)gradientStart
              gradientEnd:(UIColor *)gradientEnd
                 reaction:(NSString *)reaction
               themeColor:(UIColor *)themeColor
{
  _isUser = isUser;
  self.label.text = text;
  self.label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  
  if (isUser) {
    self.leadingConstraint.active = NO;
    self.trailingConstraint.active = YES;
    self.gradientLayer.hidden = YES;
    self.bubbleView.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0];
  } else {
    self.leadingConstraint.active = YES;
    self.trailingConstraint.active = NO;
    self.gradientLayer.hidden = NO;
    self.bubbleView.backgroundColor = [UIColor clearColor];
    self.gradientLayer.colors = @[
        (id)gradientStart.CGColor,
        (id)gradientEnd.CGColor,
    ];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
  }
  if (isUser) {
    [self updateReadReceiptWithReadByCharacterAt:readByCharacterAt isUser:isUser];
  } else {
    self.readReceiptImageView.hidden = YES;
  }

  BOOL hasReaction = reaction.length > 0;
  self.reactionContainer.hidden = !hasReaction;
  self.reactionLabel.text = reaction;
  UIColor *reactionBackground = themeColor ?: [UIColor whiteColor];
  CGFloat r = 0, g = 0, b = 0, a = 0;
  if ([reactionBackground getRed:&r green:&g blue:&b alpha:&a]) {
    // Avoid pure black; use a slightly lifted dark tone instead.
    if (r < 0.02 && g < 0.02 && b < 0.02) {
      reactionBackground = [UIColor colorWithRed:0.118 green:0.118 blue:0.118 alpha:1.0];
    }
  }
  self.reactionContainer.backgroundColor = reactionBackground;
  self.reactionLeadingConstraint.active = isUser;
  self.reactionTrailingConstraint.active = !isUser;
  self.reactionTopConstraint.constant = hasReaction ? -6.0 : 0.0;

  self.labelTrailingConstraint.constant = isUser ? -25.0 : -12.0;
  self.topConstraint.constant = sameAsPrevious ? 0.0 : 12.0;

  [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self layoutIfNeeded];
    self.gradientLayer.frame = _bubbleView.bounds;
    [CATransaction commit];
}

- (void)updateReadReceiptWithReadByCharacterAt:(double)readByCharacterAt
                                        isUser:(BOOL)isUser
{
  if (!isUser) {
    self.readReceiptImageView.hidden = YES;
    return;
  }

  self.readReceiptImageView.hidden = NO;
  NSString *imageName = (readByCharacterAt != 0.0) ? @"checkmark.circle.fill" : @"checkmark.circle";
  self.readReceiptImageView.image = [UIImage systemImageNamed:imageName];
}

- (void)updateReaction:(NSString *)reaction themeColor:(UIColor *)themeColor isUser:(BOOL)isUser
{
  BOOL hasReaction = reaction.length > 0;
  self.reactionContainer.hidden = !hasReaction;
  self.reactionLabel.text = reaction;
  
  UIColor *reactionBackground = themeColor ?: [UIColor whiteColor];
  CGFloat r = 0, g = 0, b = 0, a = 0;
  if ([reactionBackground getRed:&r green:&g blue:&b alpha:&a]) {
    if (r < 0.02 && g < 0.02 && b < 0.02) {
      reactionBackground = [UIColor colorWithRed:0.118 green:0.118 blue:0.118 alpha:1.0];
    }
  }
  self.reactionContainer.backgroundColor = reactionBackground;
  self.reactionLeadingConstraint.active = isUser;
  self.reactionTrailingConstraint.active = !isUser;
  self.reactionTopConstraint.constant = hasReaction ? -6.0 : 0.0;
}


- (void)configureWithImage:(NSDictionary * _Nullable)image
{
  // Clear existing image views
  for (UIView *subview in [_imageStackView.arrangedSubviews copy]) {
    [_imageStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  BOOL hasImage = (image != nil);
  _minWidthConstraint.active = hasImage;
  self.labelTopToBubbleConstraint.active = !hasImage;
  self.labelTopToImageConstraint.active = hasImage;

  if (!hasImage) return;

  NSString *urlString = image[@"public_url"];
  NSString *filenameString = image[@"original_filename"];

  UIImageView *imageView = [[UIImageView alloc] init];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.contentMode = UIViewContentModeScaleAspectFill;
  imageView.clipsToBounds = YES;
  imageView.userInteractionEnabled = YES;
  imageView.tag = 0; // Only one image now
  [imageView.heightAnchor constraintEqualToConstant:200.0].active = YES;
  imageView.layer.cornerRadius = 18.0;
  imageView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;

  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleImageTap:)];
  [imageView addGestureRecognizer:tap];
  [_imageStackView addArrangedSubview:imageView];

  // Helper block to set image on main thread
  void (^setImageFromData)(NSData *) = ^(NSData *data){
    if (!data) return;
    UIImage *downloadedImage = [UIImage imageWithData:data];
    dispatch_async(dispatch_get_main_queue(), ^{
      imageView.image = downloadedImage;
    });
  };

  // 1) If public_url exists and is valid, fetch it (remote)
  if (urlString.length > 0) {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url && url.scheme.length > 0) {
      NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
          setImageFromData(data);
        } else {
          // If remote fetch fails, fall back to filename below
          [self loadImageFromFilename:filenameString intoImageView:imageView completion:setImageFromData];
        }
      }];
      [task resume];
      return;
    }
    // If urlString was not a valid URL, attempt filename fallback below
  }

  // 2) No valid public_url, try to load from filename fallback
  [self loadImageFromFilename:filenameString intoImageView:imageView completion:setImageFromData];
}

// Separate helper method to handle filename cases and background loading
- (void)loadImageFromFilename:(NSString *)filename intoImageView:(UIImageView *)imageView completion:(void(^)(NSData *))completion
{
  if (!filename || filename.length == 0) {
    return;
  }

  // If filename looks like a full URL string, handle it via URLSession
  NSURL *maybeURL = [NSURL URLWithString:filename];
  if (maybeURL && maybeURL.scheme.length > 0) {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:maybeURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      if (data && !error) {
        completion(data);
      }
    }];
    [task resume];
    return;
  }

  // If it's an absolute path
  if ([filename hasPrefix:@"/"]) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
      if ([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
        NSData *data = [NSData dataWithContentsOfFile:filename];
        completion(data);
      }
    });
    return;
  }

  // Try app bundle (filename may include extension)
  NSString *name = [filename stringByDeletingPathExtension];
  NSString *ext = [filename pathExtension];
  NSString *bundlePath = nil;
  if (ext.length > 0) {
    bundlePath = [[NSBundle mainBundle] pathForResource:name ofType:ext];
  } else {
    // no extension provided — try common image extensions
    NSArray *exts = @[@"png", @"jpg", @"jpeg", @"gif", @"heic"];
    for (NSString *tryExt in exts) {
      bundlePath = [[NSBundle mainBundle] pathForResource:filename ofType:tryExt];
      if (bundlePath) break;
    }
  }

  if (bundlePath) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
      NSData *data = [NSData dataWithContentsOfFile:bundlePath];
      completion(data);
    });
    return;
  }

  // Try Documents directory (or Caches)
  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  if (documentsPath) {
    NSString *fullPath = [documentsPath stringByAppendingPathComponent:filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:fullPath];
        completion(data);
      });
      return;
    }
  }

  // Optionally: try Caches directory
  NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
  if (cachesPath) {
    NSString *fullPath = [cachesPath stringByAppendingPathComponent:filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:fullPath];
        completion(data);
      });
      return;
    }
  }
}

- (void)handleImageTap:(UITapGestureRecognizer *)recognizer
{
  UIView *imageView = recognizer.view;
  NSInteger index = imageView.tag;
  
  // Convert frame to window coordinates (like your JS measure callback)
  UIWindow *window = self.window;
  CGRect frameInWindow = [imageView convertRect:imageView.bounds toView:window];
  
  if (self.onImageTapped) {
    self.onImageTapped(index, frameInWindow);
  }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
    static BOOL didTrigger = NO;
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            didTrigger = NO;
            // Shrink animation
            [UIView animateWithDuration:0.15 animations:^{
                self.bubbleView.transform = CGAffineTransformMakeScale(0.95, 0.95);
            }];
            
            // Schedule trigger after 400ms total
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (recognizer.state == UIGestureRecognizerStateChanged ||
                    recognizer.state == UIGestureRecognizerStateBegan) {
                    didTrigger = YES;
                    [self triggerContextMenu];
                }
            });
            break;
        }
        case UIGestureRecognizerStateEnded: {
            if (!didTrigger) {
                // Reset if released too early
                [UIView animateWithDuration:0.15 animations:^{
                    self.bubbleView.transform = CGAffineTransformIdentity;
                }];
            }
            break;
        }
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            [UIView animateWithDuration:0.15 animations:^{
                self.bubbleView.transform = CGAffineTransformIdentity;
            }];
            break;
        }
        default:
            break;
    }
}

- (void)triggerContextMenu
{
    // Reset transform before snapshot
    self.bubbleView.transform = CGAffineTransformIdentity;
    
    // Create snapshot
    UIView *snapshot = [self.bubbleView snapshotViewAfterScreenUpdates:YES];
    
    // Get frame in window
    UIWindow *window = self.window;
    CGRect frameInWindow = [self.bubbleView convertRect:self.bubbleView.bounds toView:window];
    
    // Add reaction snapshot if visible
    if (!self.reactionContainer.hidden) {
        UIView *reactionSnapshot = [self.reactionContainer snapshotViewAfterScreenUpdates:YES];
        CGRect reactionFrameInBubble = [self.reactionContainer convertRect:self.reactionContainer.bounds toView:self.bubbleView];
        reactionSnapshot.frame = reactionFrameInBubble;
        [snapshot addSubview:reactionSnapshot];
    }
    
    // Call the callback
    if (self.onLongPress) {
        self.onLongPress(snapshot, frameInWindow, self.label.text, _isUser, self.bubbleView);
    }
}

@end
