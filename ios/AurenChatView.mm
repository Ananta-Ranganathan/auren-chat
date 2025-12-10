#import "AurenChatView.h"

#import <react/renderer/components/AurenChatViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/AurenChatViewSpec/EventEmitters.h>
#import <react/renderer/components/AurenChatViewSpec/Props.h>
#import <react/renderer/components/AurenChatViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import "RCTChatMessageCell.h"
#import "RCTTypingIndicatorCell.h"

using namespace facebook::react;

@interface AurenChatView () <RCTAurenChatViewViewProtocol, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@end

@implementation AurenChatView {
  UICollectionView *_collectionView;
  std::vector<AurenChatViewMessagesStruct> _messages;
  AurenChatViewThemeStruct _theme;
  CGFloat _keyboardBottomInset;
  std::unordered_set<std::string> _animatedMessageClientIDs;
  UIColor *_botGradientStart;
  UIColor *_botGradientEnd;
  UIColor *_themeBaseColor;
  CGFloat _composerHeight;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
    return concreteComponentDescriptorProvider<AurenChatViewComponentDescriptor>();
}

UIColor *colorFromHex(const std::string &hex) {
    NSString *hexString = [NSString stringWithUTF8String:hex.c_str()];
    unsigned int hexInt = 0;
    [[NSScanner scannerWithString:[hexString substringFromIndex:1]] scanHexInt:&hexInt];
    return [UIColor colorWithRed:((hexInt >> 16) & 0xFF) / 255.0
                           green:((hexInt >> 8) & 0xFF) / 255.0
                            blue:(hexInt & 0xFF) / 255.0
                           alpha:1.0];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const AurenChatViewProps>();
    _props = defaultProps;

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumLineSpacing = 0.0;
    layout.sectionInset = UIEdgeInsetsZero;
    layout.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize;
    layout.itemSize = UICollectionViewFlowLayoutAutomaticSize;

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                         collectionViewLayout:layout];

    _collectionView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.alwaysBounceVertical = YES;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

    [_collectionView registerClass:[RCTChatMessageCell class]
        forCellWithReuseIdentifier:@"RCTChatMessageCell"];
    [_collectionView registerClass:[RCTTypingIndicatorCell class]
        forCellWithReuseIdentifier:@"RCTTypingIndicatorCell"];

    // This is the key line: let Fabric size this view directly
    self.contentView = _collectionView;

    _keyboardBottomInset = 0;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(handleKeyboardNotification:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleKeyboardNotification:)
                   name:UIKeyboardWillHideNotification
                 object:nil];

    UITapGestureRecognizer *tap =
      [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapOutside:)];
    tap.cancelsTouchesInView = NO;
    [_collectionView addGestureRecognizer:tap];
  }
  return self;
}


- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  if (!props) {
    [super updateProps:props oldProps:oldProps];
    return;
  }

  const auto &newViewProps =
      *std::static_pointer_cast<AurenChatViewProps const>(props);
  
  _collectionView.backgroundColor = colorFromHex(newViewProps.theme.mode);
  _themeBaseColor = colorFromHex(newViewProps.theme.mode);
  _botGradientStart = colorFromHex(newViewProps.theme.color1);
  _botGradientEnd = colorFromHex(newViewProps.theme.color2);
  if (oldProps) {
      const auto &oldViewProps = *std::static_pointer_cast<AurenChatViewProps const>(oldProps);
      if (oldViewProps.theme.color1 != newViewProps.theme.color1 ||
          oldViewProps.theme.color2 != newViewProps.theme.color2 ||
          oldViewProps.theme.mode != newViewProps.theme.mode) {
          [_collectionView reloadData];
      }
  }
  
  CGFloat composerHeight = newViewProps.composerHeight;
  if (composerHeight != _composerHeight) {
    CGFloat delta = composerHeight - _composerHeight;
    _composerHeight = composerHeight;
    
    UIEdgeInsets newInsets = _collectionView.contentInset;
    newInsets.bottom = _keyboardBottomInset + composerHeight;
    _collectionView.contentInset = newInsets;
    _collectionView.verticalScrollIndicatorInsets = newInsets;
    
    if (delta > 0) {
        CGPoint offset = _collectionView.contentOffset;
        offset.y += delta;
        _collectionView.contentOffset = offset;
    }
  }
  
  // Build new messages vector
  std::vector<AurenChatViewMessagesStruct> newMessages;
  newMessages.reserve(newViewProps.messages.size());
  for (const auto &msg : newViewProps.messages) {
    newMessages.push_back(msg);
  }

  // Check if we're at the bottom before changes
  CGFloat contentHeight = _collectionView.contentSize.height;
  CGFloat visibleHeight = _collectionView.bounds.size.height;
  UIEdgeInsets insets = _collectionView.contentInset;
  CGFloat bottomOffset = MAX(contentHeight + insets.bottom - visibleHeight, -insets.top);
  CGFloat currentOffsetY = _collectionView.contentOffset.y;
  BOOL wasAtBottom = (contentHeight <= visibleHeight) || (currentOffsetY >= bottomOffset - 2.0);

  // Build UUID lookup for old messages
  std::unordered_map<std::string, NSInteger> oldIndexByUUID;
  for (NSInteger i = 0; i < (NSInteger)_messages.size(); i++) {
    oldIndexByUUID[_messages[i].uuid] = i;
  }

  // Build UUID lookup for new messages
  std::unordered_map<std::string, NSInteger> newIndexByUUID;
  for (NSInteger i = 0; i < (NSInteger)newMessages.size(); i++) {
    newIndexByUUID[newMessages[i].uuid] = i;
  }

  // Find deletes, inserts, and reloads
  NSMutableArray<NSIndexPath *> *toDelete = [NSMutableArray new];
  NSMutableArray<NSIndexPath *> *toInsert = [NSMutableArray new];
  NSMutableArray<NSIndexPath *> *toReload = [NSMutableArray new];
  NSMutableArray<NSIndexPath *> *toReconfigure = [NSMutableArray new];

  // Check for deletions (in old but not in new)
  for (NSInteger i = 0; i < (NSInteger)_messages.size(); i++) {
    if (newIndexByUUID.find(_messages[i].uuid) == newIndexByUUID.end()) {
      [toDelete addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    }
  }

  // Check for insertions and updates
  for (NSInteger i = 0; i < (NSInteger)newMessages.size(); i++) {
    auto it = oldIndexByUUID.find(newMessages[i].uuid);
    if (it == oldIndexByUUID.end()) {
      // New message
      [toInsert addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    } else {
      // Reload for typing indicators
      NSInteger oldIndex = it->second;
      if (_messages[oldIndex].isTypingIndicator != newMessages[i].isTypingIndicator) {
        [toReload addObject:[NSIndexPath indexPathForItem:i inSection:0]];
      } else if (_messages[oldIndex].readByCharacterAt != newMessages[i].readByCharacterAt) {
        [toReconfigure addObject:[NSIndexPath indexPathForItem:i inSection:0]];
      }
    }
  }

  BOOL hasStructuralChanges = toDelete.count > 0 || toInsert.count > 0 || toReload.count > 0;
  BOOL hasReadReceiptChanges = toReconfigure.count > 0;

  auto scrollToBottomIfNeeded = ^{
      if (wasAtBottom && self->_messages.size() > 0) {
          NSInteger lastSection = [self->_collectionView numberOfSections] - 1;
          NSInteger lastItemIndex = [self->_collectionView numberOfItemsInSection:lastSection] - 1;

          if (lastSection >= 0 && lastItemIndex >= 0) {
              NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:lastItemIndex inSection:lastSection];
              [self->_collectionView scrollToItemAtIndexPath:lastIndexPath
                                            atScrollPosition:UICollectionViewScrollPositionBottom
                                                    animated:YES];
          }
      }
  };

  if (hasStructuralChanges) {
    [_collectionView performBatchUpdates:^{
      self->_messages = std::move(newMessages);
      
      if (toDelete.count > 0) {
        [self->_collectionView deleteItemsAtIndexPaths:toDelete];
      }
      if (toInsert.count > 0) {
        [self->_collectionView insertItemsAtIndexPaths:toInsert];
      }
      if (toReload.count > 0) {
        [self->_collectionView reloadItemsAtIndexPaths:toReload];
      }
    } completion:^(__unused BOOL finished) {
      if (hasReadReceiptChanges) {
        [self applyReadReceiptUpdates:toReconfigure];
      }
    }];
    scrollToBottomIfNeeded();
  } else if (hasReadReceiptChanges) {
    self->_messages = std::move(newMessages);
    [self applyReadReceiptUpdates:toReconfigure];
  } else {
    _messages = std::move(newMessages);
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)applyReadReceiptUpdates:(NSArray<NSIndexPath *> *)indexPaths
{
  for (NSIndexPath *indexPath in indexPaths) {
    if (indexPath.item >= (NSInteger)_messages.size()) {
      continue;
    }
    UICollectionViewCell *cell = [_collectionView cellForItemAtIndexPath:indexPath];
    if (![cell isKindOfClass:[RCTChatMessageCell class]]) {
      continue;
    }
    const auto &message = _messages[(size_t)indexPath.item];
    [(RCTChatMessageCell *)cell updateReadReceiptWithReadByCharacterAt:message.readByCharacterAt
                                                                isUser:message.isUser];
  }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
  return (NSInteger)_messages.size();
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  const auto &msg = _messages[(size_t)indexPath.item];
  
  if (msg.isTypingIndicator) {
    RCTTypingIndicatorCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"RCTTypingIndicatorCell"
                                                  forIndexPath:indexPath];
    [cell configureWithIsUser:msg.isUser gradientStart:_botGradientStart gradientEnd:_botGradientEnd];
    [cell startAnimating];
    return cell;
  }
  
  RCTChatMessageCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:@"RCTChatMessageCell"
                                                forIndexPath:indexPath];
  
  BOOL sameAsPrevious = NO;
  if (indexPath.item > 0) {
    const auto &prevMsg = _messages[(size_t)(indexPath.item - 1)];
    sameAsPrevious = (prevMsg.isUser == msg.isUser) && !prevMsg.isTypingIndicator;
  }

  NSString *text = [NSString stringWithUTF8String:msg.text.c_str()];
  NSString *reaction = [NSString stringWithUTF8String:msg.reaction.c_str()];
  [cell configureWithText:text
                   isUser:msg.isUser
           sameAsPrevious:sameAsPrevious
       readByCharacterAt:msg.readByCharacterAt
            gradientStart:_botGradientStart
              gradientEnd:_botGradientEnd
                 reaction:reaction
               themeColor:_themeBaseColor];

  // Convert C++ image to NSDictionary
  // Build a mutable dictionary and only add keys when present
  NSMutableDictionary *imageDict = [NSMutableDictionary dictionary];

  if (!msg.image.publicUrl.empty()) {
      NSString *publicUrl = [NSString stringWithUTF8String:msg.image.publicUrl.c_str()];
      if (publicUrl) { // stringWithUTF8String returns nil on invalid UTF-8
          imageDict[@"public_url"] = publicUrl;
      }
  }

  if (!msg.image.originalFilename.empty()) {
      NSString *filename = [NSString stringWithUTF8String:msg.image.originalFilename.c_str()];
      if (filename) {
          imageDict[@"original_filename"] = filename;
      }
  }

  // If no keys were added, pass nil; otherwise pass an immutable copy
  NSDictionary *finalImageDict = (imageDict.count > 0) ? [imageDict copy] : nil;
  [cell configureWithImage:finalImageDict];

  // Set up tap callback to emit event
//  NSString *messageUuid = [NSString stringWithUTF8String:msg.uuid.c_str()];
//  cell.onImageTapped = ^(NSInteger imageIndex, CGRect frameInWindow) {
//    if (self->_eventEmitter) {
//      auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(self->_eventEmitter);
//      if (emitter) {
//        emitter->onImagePress({
//          .messageUuid = std::string([messageUuid UTF8String]),
//          .imageIndex = static_cast<int>(imageIndex),
//          .x = frameInWindow.origin.x,
//          .y = frameInWindow.origin.y,
//          .width = frameInWindow.size.width,
//          .height = frameInWindow.size.height,
//        });
//      }
//    }
//  };
  
  return cell;
}
- (void)handleKeyboardNotification:(NSNotification *)notification
{
  NSDictionary *userInfo = notification.userInfo;
  if (!userInfo) {
    return;
  }

  NSTimeInterval duration =
      [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  UIViewAnimationOptions curve =
      ([userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);

  CGRect keyboardFrameScreen =
      [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];

  // Convert keyboard frame into this view's coordinate space
  CGRect keyboardFrameInSelf = [self convertRect:keyboardFrameScreen
                                        fromView:nil];

  // How much of our bounds is covered by the keyboard?
  CGFloat overlap =
      CGRectGetMaxY(self.bounds) - CGRectGetMinY(keyboardFrameInSelf);
  CGFloat newBottomInset = MAX(overlap, 0.0);


  UIEdgeInsets oldContentInsets = _collectionView.contentInset;
  UIEdgeInsets oldIndicatorInsets = _collectionView.verticalScrollIndicatorInsets;

  // Compute whether we are currently at the bottom (before insets change)
  CGFloat contentHeight = _collectionView.contentSize.height;
  CGFloat visibleHeight = _collectionView.bounds.size.height;

  // Where is the bottom offset with the old insets?
  CGFloat oldBottomOffset =
      MAX(contentHeight + oldContentInsets.bottom - visibleHeight, -oldContentInsets.top);

  CGFloat currentOffsetY = _collectionView.contentOffset.y;
  BOOL wasAtBottom = fabs(currentOffsetY - oldBottomOffset) < 2.0; // small tolerance

  // New insets
  UIEdgeInsets newContentInsets = oldContentInsets;
  newContentInsets.bottom = newBottomInset + _composerHeight;

  UIEdgeInsets newIndicatorInsets = oldIndicatorInsets;
  newIndicatorInsets.bottom = newBottomInset + _composerHeight;

  CGFloat deltaBottom = newContentInsets.bottom - oldContentInsets.bottom;
  CGPoint newOffset = _collectionView.contentOffset;

  if (wasAtBottom) {
      CGFloat newBottomOffset =
          MAX(contentHeight + newContentInsets.bottom - visibleHeight,
              -newContentInsets.top);
      newOffset.y = newBottomOffset;
  } else {
      newOffset.y += deltaBottom;
      if (newOffset.y < -newContentInsets.top) {
          newOffset.y = -newContentInsets.top;
      }
  }

  [UIView animateWithDuration:duration
                        delay:0
                      options:curve
                   animations:^{
                       self->_keyboardBottomInset = newBottomInset;
                       self->_collectionView.contentInset = newContentInsets;
                       self->_collectionView.verticalScrollIndicatorInsets = newIndicatorInsets;
                       self->_collectionView.contentOffset = newOffset;
                   }
                   completion:nil];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  const auto &msg = _messages[(size_t)indexPath.item];
    CGFloat contentWidth = collectionView.bounds.size.width;
  BOOL sameAsPrevious = NO;
  if (indexPath.item > 0) {
    const auto &prevMsg = _messages[(size_t)(indexPath.item - 1)];
    sameAsPrevious = (prevMsg.isUser == msg.isUser) && !prevMsg.isTypingIndicator;
  }
  CGFloat verticalSpacing = sameAsPrevious ? 0.0 : 8.0;
    
  if (msg.isTypingIndicator) {
    CGFloat textHeight = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].lineHeight;
    CGFloat cellHeight = ceil(textHeight) + 2 * 10.0 + 8.0 + verticalSpacing;
    return CGSizeMake(contentWidth, cellHeight);
  }
    
    NSString *text = [NSString stringWithUTF8String:msg.text.c_str()];
    
    CGFloat maxBubbleWidth = contentWidth * 0.75;
    CGFloat labelPaddingHorizontal = 16.0;
    CGFloat labelPaddingVertical = 10.0;
    CGFloat maxLabelWidth = maxBubbleWidth - 2 * labelPaddingHorizontal;
    
    CGRect textRect = [text boundingRectWithSize:CGSizeMake(maxLabelWidth, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody]}
                                         context:nil];
    CGFloat imageHeight = 0;
    if (!msg.image.publicUrl.empty() || !msg.image.originalFilename.empty()) {
        imageHeight = 200.0;
    }

    CGFloat cellHeight = ceil(textRect.size.height) + 2 * labelPaddingVertical + 8.0 + verticalSpacing + imageHeight;
    
    return CGSizeMake(contentWidth, cellHeight);
  }

- (void)handleTapOutside:(UITapGestureRecognizer *)recognizer
{
    CGPoint location = [recognizer locationInView:_collectionView];
    NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:location];
    
    BOOL shouldDismiss = NO;
    
    if (indexPath == nil) {
        shouldDismiss = YES;
    } else {
        RCTChatMessageCell *cell = (RCTChatMessageCell *)[_collectionView cellForItemAtIndexPath:indexPath];
        CGPoint pointInCell = [recognizer locationInView:cell];
        
        if (![cell.bubbleView pointInside:[cell.bubbleView convertPoint:pointInCell fromView:cell] withEvent:nil]) {
            shouldDismiss = YES;
        }
    }
    
    if (shouldDismiss && _eventEmitter) {
        auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(_eventEmitter);
        if (emitter) {
            emitter->onRequestDismissKeyboard({});
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
  AurenChatViewMessagesStruct message = _messages[indexPath.item];
  if (_animatedMessageClientIDs.find(message.uuid) != _animatedMessageClientIDs.end()) {
    cell.alpha = 1;
    cell.transform = CGAffineTransformIdentity;
    NSLog(@"skipping anim for index%ld", (long)indexPath.item);
    return;
  }
  if (!message.isTypingIndicator) {
    _animatedMessageClientIDs.insert(message.uuid);
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    cell.alpha = 0;
    CGAffineTransform t = CGAffineTransformMakeScale(0.5, 0.5);

    if (message.isUser) {
      cell.transform = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(-20, 0));
    } else {
      cell.transform = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(20, 0));
    }
    [UIView animateWithDuration:0.25
                      delay:0
                      options:UIViewAnimationOptionCurveEaseOut
                      animations:^{
                        cell.alpha = 1;
                        cell.transform = CGAffineTransformIdentity;
                      } completion:nil];
  });
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

Class<RCTComponentViewProtocol> AurenChatViewCls(void)
{
    return AurenChatView.class;
}



@end
