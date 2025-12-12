#import "AurenChatView.h"

#import <react/renderer/components/AurenChatViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/AurenChatViewSpec/EventEmitters.h>
#import <react/renderer/components/AurenChatViewSpec/Props.h>
#import <react/renderer/components/AurenChatViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import "RCTChatMessageCell.h"
#import "RCTTypingIndicatorCell.h"
#import "RCTContextMenuOverlayView.h"

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
  BOOL _contextMenuActive;
  BOOL _keyboardWasVisible;
  BOOL _settingsModalActive;
  BOOL _isLoadingOlderMessages;
  BOOL _isLoadingNewerMessages;
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
  _settingsModalActive = newViewProps.settingsModalActive;
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
    
    if (!_contextMenuActive) {
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
  BOOL wasAtBottom = (contentHeight <= visibleHeight) || (currentOffsetY >= bottomOffset - 150.0);

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
      } else if (_messages[oldIndex].readByCharacterAt != newMessages[i].readByCharacterAt ||
                 _messages[oldIndex].reaction != newMessages[i].reaction) {
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
      BOOL isPrepend = NO;
      if (newMessages.size() > _messages.size() && _messages.size() > 0 && newMessages.size() > 0) {
          if (newMessages[0].uuid != _messages[0].uuid) {
              isPrepend = YES;
          }
      }
      
    if (isPrepend) {
      NSLog(@"prepending!");
        CGFloat oldContentHeight = _collectionView.contentSize.height;
        CGPoint oldOffset = _collectionView.contentOffset;
        
        NSInteger prependedCount = (NSInteger)toInsert.count;
        
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        [_collectionView performBatchUpdates:^{
            self->_messages = std::move(newMessages);
            
            if (toInsert.count > 0) {
                [self->_collectionView insertItemsAtIndexPaths:toInsert];
            }
            

        } completion:nil];
        
        [_collectionView layoutIfNeeded];
        
        CGFloat newContentHeight = _collectionView.contentSize.height;
        CGFloat addedHeight = newContentHeight - oldContentHeight;
        
        if (addedHeight > 0) {
            CGPoint adjustedOffset = oldOffset;
            adjustedOffset.y += addedHeight;
            _collectionView.contentOffset = adjustedOffset;
        }
      
      // Reload the first previously-existing message (its sameAsPrevious may have changed)
      if (prependedCount > 0) {
        NSLog(@"Message at index %ld (last prepended): isUser=%d",
              (long)(prependedCount - 1),
              self->_messages[prependedCount - 1].isUser);
        NSLog(@"Message at index %ld (first old): isUser=%d",
              (long)prependedCount,
              self->_messages[prependedCount].isUser);
          NSIndexPath *firstOldMessage = [NSIndexPath indexPathForItem:prependedCount inSection:0];
          [self->_collectionView reloadItemsAtIndexPaths:@[firstOldMessage]];
      }
        
        [CATransaction commit];
        
        _isLoadingOlderMessages = NO;
        
        if (hasReadReceiptChanges) {
            [self applyReadReceiptUpdates:toReconfigure];
        }
    } else {
          // For non-prepends: use batch updates as before
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
          } completion:^(BOOL finished) {
              if (hasReadReceiptChanges) {
                  [self applyReadReceiptUpdates:toReconfigure];
              }
          }];
          scrollToBottomIfNeeded();
      }
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
    RCTChatMessageCell *msgCell = (RCTChatMessageCell *)cell;
    [msgCell updateReadReceiptWithReadByCharacterAt:message.readByCharacterAt
                                             isUser:message.isUser];
    NSString *reaction = [NSString stringWithUTF8String:message.reaction.c_str()];
    [msgCell updateReaction:reaction themeColor:_themeBaseColor isUser:message.isUser];
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
  NSLog(@"Cell at index %ld, sameAsPrevious: %d, isUser: %d", (long)indexPath.item, sameAsPrevious, msg.isUser);

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
  
  NSString *messageUuid = [NSString stringWithUTF8String:msg.uuid.c_str()];
  NSArray *favoriteEmojis = @[@"❤️", @"😂", @"🤔", @"👍", @"👎", @"❗️"]; // Or from props

  cell.onLongPress = ^(UIView *snapshot, CGRect frame, NSString *text, BOOL isUser, UIView *bubbleView) {
      [self showContextMenuWithSnapshot:snapshot
                                  frame:frame
                                   text:text
                                 isUser:isUser
                            messageUuid:messageUuid
                         favoriteEmojis:favoriteEmojis
                             bubbleView:bubbleView];
  };

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
  cell.layer.zPosition = (CGFloat)indexPath.item;

  return cell;
}
- (void)handleKeyboardNotification:(NSNotification *)notification
{
  if (_contextMenuActive) {
    return;
  }
  if (_settingsModalActive) {
    return;
  }
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
                       self->_keyboardWasVisible = (newBottomInset > 0);
                       self->_collectionView.contentInset = newContentInsets;
                       self->_collectionView.verticalScrollIndicatorInsets = newIndicatorInsets;
                       self->_collectionView.contentOffset = newOffset;
                   }
                   completion:nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Don't request if already loading or context menu is active
    if (_isLoadingOlderMessages || _contextMenuActive) {
        return;
    }
    
    // Check if we're near the top (within 100 points)
    if (scrollView.contentOffset.y < 100) {
        if (_eventEmitter) {
            auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(_eventEmitter);
            if (emitter) {
                _isLoadingOlderMessages = _messages.size() > 0;
                emitter->onRequestOlderMessages({});
            }
        }
    }
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
  CGFloat verticalSpacing = sameAsPrevious ? 0.0 : 12.0;
    
  if (msg.isTypingIndicator) {
    CGFloat textHeight = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].lineHeight;
    CGFloat cellHeight = ceil(textHeight) + 2 * 10.0 + 8.0 + verticalSpacing;
    return CGSizeMake(contentWidth, cellHeight);
  }
    
    NSString *text = [NSString stringWithUTF8String:msg.text.c_str()];
    
    CGFloat maxBubbleWidth = contentWidth * 0.75;
    CGFloat labelPaddingHorizontal = 16.0;
  CGFloat labelPaddingVertical = 8.0;
  CGFloat bubbleVertical = 4.0;
    CGFloat maxLabelWidth = maxBubbleWidth - 2 * labelPaddingHorizontal;
    
    CGRect textRect = [text boundingRectWithSize:CGSizeMake(maxLabelWidth, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody]}
                                         context:nil];
    CGFloat imageHeight = 0;
    if (!msg.image.publicUrl.empty() || !msg.image.originalFilename.empty()) {
        imageHeight = 200.0;
    }

  CGFloat cellHeight = ceil(textRect.size.height) + 2 * labelPaddingVertical + bubbleVertical + verticalSpacing + imageHeight;
    
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
    NSLog(@"skipping anim for index%ld because already animated for this uuid", (long)indexPath.item);
    return;
  }
  if (message.skipAnimation) {
    cell.alpha = 1;
    cell.transform = CGAffineTransformIdentity;
    NSLog(@"skipping anim for index%ld because skip configured", (long)indexPath.item);
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

- (void)showContextMenuWithSnapshot:(UIView *)snapshot
                              frame:(CGRect)frame
                               text:(NSString *)text
                             isUser:(BOOL)isUser
                        messageUuid:(NSString *)messageUuid
                     favoriteEmojis:(NSArray<NSString *> *)emojis
                         bubbleView:(UIView *)bubbleView
{
    UIWindow *window = self.window;
    
    RCTContextMenuOverlayView *overlay = [[RCTContextMenuOverlayView alloc] initWithFrame:window.bounds];
  
    overlay.onToggleOriginalBubble = ^(BOOL hidden) {
        bubbleView.hidden = hidden;
    };
    
    overlay.onReply = ^{
        if (self->_eventEmitter) {
            auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(self->_eventEmitter);
            if (emitter) {
                emitter->onReply({.messageUuid = std::string([messageUuid UTF8String])});
            }
        }
    };
    
    overlay.onCopy = ^(NSString *copiedText) {
        if (self->_eventEmitter) {
            auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(self->_eventEmitter);
            if (emitter) {
                emitter->onCopy({.messageUuid = std::string([messageUuid UTF8String])});
            }
        }
    };
    
    overlay.onReactionSelect = ^(NSString *emoji) {
        if (self->_eventEmitter) {
            auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(self->_eventEmitter);
            if (emitter) {
                emitter->onReactionSelect({
                    .messageUuid = std::string([messageUuid UTF8String]),
                    .emoji = std::string([emoji UTF8String])
                });
            }
        }
    };
    
    overlay.onEmojiPickerOpen = ^{
        if (self->_eventEmitter) {
            auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(self->_eventEmitter);
            if (emitter) {
                emitter->onEmojiPickerOpen({.messageUuid = std::string([messageUuid UTF8String])});
            }
        }
    };
  

    BOOL hadKeyboard = _keyboardWasVisible;
    _contextMenuActive = YES;
    overlay.onDismiss = ^{
        self->_contextMenuActive = NO;
        if (self->_eventEmitter) {
            auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(self->_eventEmitter);
            if (emitter) {
                emitter->onContextMenuDismiss({.shouldRefocusComposer = hadKeyboard});
            }
        }
    };
    auto emitter = std::dynamic_pointer_cast<const AurenChatViewEventEmitter>(_eventEmitter);
    if (emitter) {
        emitter->onRequestDismissKeyboard({});
    }
  
    [window addSubview:overlay];
    CGFloat r = 0, g = 0, b = 0, a = 0;
    BOOL isDarkMode = NO;
    if ([_themeBaseColor getRed:&r green:&g blue:&b alpha:&a]) {
        isDarkMode = (r < 0.1 && g < 0.1 && b < 0.1);
    }

    [overlay showWithBubbleSnapshot:snapshot
                        bubbleFrame:frame
                        messageText:text
                             isUser:isUser
                     favoriteEmojis:emojis
                         isDarkMode:isDarkMode];
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
