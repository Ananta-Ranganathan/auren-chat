//
//  RCTTypingIndicatorCell.mm
//  Pods
//
//  Created by Ananta Ranganathan on 12/8/25.
//


#import "RCTTypingIndicatorCell.h"

@implementation RCTTypingIndicatorCell {
  UIView *_dot1;
  UIView *_dot2;
  UIView *_dot3;
  UIView *_dotsContainer;
  BOOL _isAnimating;
  NSLayoutConstraint *_leadingConstraint;
  NSLayoutConstraint *_trailingConstraint;
  NSInteger _animationGeneration;
  CAGradientLayer *_gradientLayer;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    _bubbleView = [UIView new];
    _bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    _bubbleView.layer.cornerRadius = 20.0;
    _bubbleView.layer.masksToBounds = YES;
    
    [self.contentView addSubview:_bubbleView];
    
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.cornerRadius = 20.0;
    [_bubbleView.layer insertSublayer:_gradientLayer atIndex:0];
    
    _dotsContainer = [UIView new];
    _dotsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_bubbleView addSubview:_dotsContainer];
    
    // Create three dots
    _dot1 = [self createDot];
    _dot2 = [self createDot];
    _dot3 = [self createDot];
    
    [_dotsContainer addSubview:_dot1];
    [_dotsContainer addSubview:_dot2];
    [_dotsContainer addSubview:_dot3];
    
    CGFloat dotSize = 6.0;
    CGFloat dotSpacing = 6.0;
    CGFloat bubblePaddingH = 16.0;
    CGFloat bubblePaddingV = 10.0;
    
    _leadingConstraint = [_bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0];
    _trailingConstraint = [_bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0];
    NSLayoutConstraint *dotsHeightConstraint = [_dotsContainer.heightAnchor constraintEqualToConstant:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].lineHeight];
    dotsHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    
    [NSLayoutConstraint activateConstraints:@[
      // Bubble vertical positioning
      [_bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4.0],
      [_bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4.0],
      
      // Dots container inside bubble
      [_dotsContainer.leadingAnchor constraintEqualToAnchor:_bubbleView.leadingAnchor constant:bubblePaddingH],
      [_dotsContainer.trailingAnchor constraintEqualToAnchor:_bubbleView.trailingAnchor constant:-bubblePaddingH],
      [_dotsContainer.topAnchor constraintEqualToAnchor:_bubbleView.topAnchor constant:bubblePaddingV],
      [_dotsContainer.bottomAnchor constraintEqualToAnchor:_bubbleView.bottomAnchor constant:-bubblePaddingV],
      
      // Dot sizes
      [_dot1.widthAnchor constraintEqualToConstant:dotSize],
      [_dot1.heightAnchor constraintEqualToConstant:dotSize],
      [_dot2.widthAnchor constraintEqualToConstant:dotSize],
      [_dot2.heightAnchor constraintEqualToConstant:dotSize],
      [_dot3.widthAnchor constraintEqualToConstant:dotSize],
      [_dot3.heightAnchor constraintEqualToConstant:dotSize],
      
      // Horizontal layout within container
      [_dot1.leadingAnchor constraintEqualToAnchor:_dotsContainer.leadingAnchor],
      [_dot2.leadingAnchor constraintEqualToAnchor:_dot1.trailingAnchor constant:dotSpacing],
      [_dot3.leadingAnchor constraintEqualToAnchor:_dot2.trailingAnchor constant:dotSpacing],
      [_dot3.trailingAnchor constraintEqualToAnchor:_dotsContainer.trailingAnchor],
      
      // Vertical centering
      [_dot1.centerYAnchor constraintEqualToAnchor:_dotsContainer.centerYAnchor],
      [_dot2.centerYAnchor constraintEqualToAnchor:_dotsContainer.centerYAnchor],
      [_dot3.centerYAnchor constraintEqualToAnchor:_dotsContainer.centerYAnchor],
    ]];
    dotsHeightConstraint.active = YES;
  }
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _gradientLayer.frame = _bubbleView.bounds;
}

- (UIView *)createDot
{
  UIView *dot = [UIView new];
  dot.translatesAutoresizingMaskIntoConstraints = NO;
  dot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
  dot.layer.cornerRadius = 3.0;
  return dot;
}

- (void)configureWithIsUser:(BOOL)isUser gradientStart:(UIColor *)gradientStart gradientEnd:(UIColor *)gradientEnd
{
  if (isUser) {
    _leadingConstraint.active = NO;
    _trailingConstraint.active = YES;
    _gradientLayer.hidden = YES;
    self.bubbleView.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0];
  } else {
    _trailingConstraint.active = NO;
    _leadingConstraint.active = YES;
    _gradientLayer.hidden = NO;
    _bubbleView.backgroundColor = [UIColor clearColor];
    _gradientLayer.colors = @[(id)gradientStart.CGColor, (id)gradientEnd.CGColor];
    _gradientLayer.startPoint = CGPointMake(0, 0);
    _gradientLayer.endPoint = CGPointMake(1, 1);
  }
  // Force layout so gradient layer gets correct frame immediately
  [self setNeedsLayout];
  [self layoutIfNeeded];
}

- (void)startAnimating
{
  if (_isAnimating) return;
  _isAnimating = YES;
  _animationGeneration++;
  NSInteger generation = _animationGeneration;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self->_isAnimating || self->_animationGeneration != generation) return;
    [self animateDot:self->_dot1 withDelay:0.0 generation:generation];
    [self animateDot:self->_dot2 withDelay:0.2 generation:generation];
    [self animateDot:self->_dot3 withDelay:0.4 generation:generation];
  });
}

- (void)animateDot:(UIView *)dot withDelay:(NSTimeInterval)delay generation:(NSInteger)generation
{
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (!self->_isAnimating || self->_animationGeneration != generation) return;
    dot.transform = CGAffineTransformMakeScale(0.5, 0.5);
    [self runScaleCycleForDot:dot generation:generation];
  });
}

- (void)runScaleCycleForDot:(UIView *)dot generation:(NSInteger)generation
{
  if (!_isAnimating || _animationGeneration != generation) return;
  
  [UIView animateWithDuration:0.3
                   animations:^{
    dot.transform = CGAffineTransformMakeScale(1.0, 1.0);
  } completion:^(BOOL finished) {
    if (!self->_isAnimating || !finished || self->_animationGeneration != generation) return;
    
    [UIView animateWithDuration:0.3
                     animations:^{
      dot.transform = CGAffineTransformMakeScale(0.5, 0.5);
    } completion:^(BOOL finished) {
      if (!self->_isAnimating || !finished || self->_animationGeneration != generation) return;
      [self runScaleCycleForDot:dot generation:generation];
    }];
  }];
}
- (void)stopAnimating
{
  _isAnimating = NO;
  [_dot1.layer removeAllAnimations];
  [_dot2.layer removeAllAnimations];
  [_dot3.layer removeAllAnimations];
  _dot1.transform = CGAffineTransformIdentity;
  _dot2.transform = CGAffineTransformIdentity;
  _dot3.transform = CGAffineTransformIdentity;
  _dot1.transform = CGAffineTransformMakeScale(0.0, 0.0);
  _dot2.transform = CGAffineTransformMakeScale(0.0, 0.0);
  _dot3.transform = CGAffineTransformMakeScale(0.0, 0.0);
}

- (void)prepareForReuse
{
  [super prepareForReuse];
  [self stopAnimating];
}

@end
