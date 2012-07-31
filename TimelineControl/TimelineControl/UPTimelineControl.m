//
//  CCVTimelineView.m
//  Chat
//
//  Created by Matthew Gillingham on 11/25/11.
//  Copyright (c) 2011 Matt Gillingham. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

#import "UPTimelineControl.h"
#import "UPTimelineMinuteView.h"

#define kRecommendedWidthPerMinute 1000.0f

static inline NSUInteger minutesFromDuration(CMTime duration) {
  return (NSInteger) floor(CMTimeGetSeconds(duration) / 60.0);
}

static inline CGFloat coordinateFromTime(CMTime time, CGFloat widthForOneMinute) {
  return (CGFloat) CMTimeGetSeconds(time) * widthForOneMinute / 60.0;
}

static inline CMTime timeFromCoordinate(CGFloat coordinate, CGFloat widthForOneMinute, int32_t preferredScale) {
  return CMTimeMakeWithSeconds(coordinate * 60.0 / widthForOneMinute, preferredScale);
}

@interface UPTimelineControl()
- (void)setupView;
- (void)setupSynchronizedLayer;
- (void)setupSelectedRangeLayer;
- (void)setupSelectionRangeAnimation:(CMTimeRange)selectedRange;
- (void)loadScrollview:(CGFloat)widthPerMinute;
- (UPTimelineMinuteView*)minuteViewWithMinute:(NSUInteger)currentMinute width:(CGFloat)width;
@end

@implementation UPTimelineControl

@synthesize playerItem = _playerItem;
@synthesize selectedRange = _selectedRange;
@synthesize widthPerMinute = _widthPerMinute;
@synthesize selecting = _selecting;
@synthesize adjusting = _adjusting;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self setupView];
  }
    
  return self;
}

- (void)awakeFromNib {
  [self setupView];
}

-(void)dealloc {
  _playerItem = nil;

  [rangeAdjustmentView release];

  [rangeAdjustmentStartImageView removeFromSuperview];
  [rangeAdjustmentStartImageView release];
  
  [rangeAdjustmentEndImageView removeFromSuperview];
  [rangeAdjustmentEndImageView release];

  [pointerSyncLayer release];
  [pointerLayer release];
  [rangeAnimationLayer release];
  [rangeAnimation release];
  [rangeSyncLayer release];
  [pointerLayer release];
  [scrollView release];
      
  [super dealloc];
}

-(void)layoutSubviews {
  if (nil == self.playerItem) {
    return;
  }
    
  scrollView.frame = self.bounds;
  
  [self loadScrollview:_widthPerMinute];
  [self setupWaveformView];
  [self setupSelectedRangeLayer];
  [self setupSynchronizedLayer];
}

-(void)setupView {
  _selectedRange = kCMTimeRangeZero;
  _widthPerMinute = kRecommendedWidthPerMinute;
  preferredScale = 1;
    
  scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
  scrollView.backgroundColor = [UIColor clearColor];
  scrollView.clipsToBounds = YES;
  scrollView.showsHorizontalScrollIndicator = NO;
  scrollView.alwaysBounceHorizontal = YES;
  scrollView.canCancelContentTouches = NO;
  
  for (UIGestureRecognizer* recognizer in [scrollView gestureRecognizers]) {
    if ([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        [recognizer setEnabled:NO];
    }
  }
  
  UIPinchGestureRecognizer* pinchRecognizer = 
    [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];
  [scrollView addGestureRecognizer:pinchRecognizer];
  [pinchRecognizer release];
  
  [self addSubview:scrollView];

  UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc]
    initWithTarget:self
    action:@selector(scrollViewLongPressed:)
  ];
  longPressGesture.delegate = self;  
  [scrollView addGestureRecognizer:longPressGesture];
  [longPressGesture release];
}

-(void)setPlayerItem:(AVPlayerItem *)playerItem {
  _playerItem = playerItem;
  
  NSAssert([[playerItem.asset tracks] count] > 0, @"The asset has no track");
  
  preferredScale = [[[playerItem.asset tracks] objectAtIndex:0] naturalTimeScale];

  [self loadScrollview:_widthPerMinute];
  [self setupWaveformView];
  [self setupSynchronizedLayer];
}

-(void)setSelectedRange:(CMTimeRange)selectedRange {
  _selectedRange = selectedRange;

  [self setupSelectedRangeLayer];
}

-(void)setupSelectionRangeAnimation:(CMTimeRange)selectedRange {     
  CGFloat selectionStartX = coordinateFromTime(self.playerItem.currentTime, _widthPerMinute);
  CGFloat selectionWidthX = coordinateFromTime(selectedRange.duration, _widthPerMinute);
  
  if (nil == rangeSyncLayer) {
    rangeSyncLayer = [[AVSynchronizedLayer synchronizedLayerWithPlayerItem:self.playerItem] retain];
    rangeSyncLayer.backgroundColor = [[UIColor clearColor] CGColor];
    [scrollView.layer insertSublayer:rangeSyncLayer below:pointerSyncLayer];
  }
  
  rangeSyncLayer.frame = CGRectMake(0.0f, 0.0f, scrollView.contentSize.width, scrollView.contentSize.height);
  
  if (nil == rangeAnimationLayer) {
    rangeAnimationLayer = [[CALayer layer] retain];
    rangeAnimationLayer.backgroundColor = [[UIColor blueColor] CGColor];
    rangeAnimationLayer.opacity = 0.5f;
    rangeAnimationLayer.anchorPoint = CGPointMake(0.0f, 0.5f);
    [rangeSyncLayer addSublayer:rangeAnimationLayer];
  }
  
  rangeAnimationLayer.position = CGPointMake(selectionStartX, rangeSyncLayer.bounds.size.height / 2.0f);
  rangeAnimationLayer.bounds = CGRectMake(0.0f, 0.0f, selectionWidthX, rangeSyncLayer.bounds.size.height);

  rangeAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
  rangeAnimation.fromValue = [NSValue valueWithCGRect:CGRectMake(
    0.0f,
    0.0f,
    0.0f,
    rangeSyncLayer.frame.size.height
  )];
  rangeAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(
    0.0f,
    0.0f,
    rangeSyncLayer.frame.size.width - selectionStartX,
    rangeSyncLayer.frame.size.height
  )];
  
  rangeAnimation.removedOnCompletion =  NO;
  rangeAnimation.beginTime = CMTimeGetSeconds(self.playerItem.currentTime);
  rangeAnimation.duration = CMTimeGetSeconds(CMTimeSubtract(self.playerItem.duration, self.playerItem.currentTime));
  [rangeAnimationLayer addAnimation:rangeAnimation forKey:@"rangeAnimation"];
}

-(void)setupSynchronizedLayer {
  if (nil == pointerSyncLayer) {
    pointerSyncLayer = [[AVSynchronizedLayer synchronizedLayerWithPlayerItem:self.playerItem] retain];
    pointerSyncLayer.backgroundColor = [[UIColor clearColor] CGColor];
    [scrollView.layer addSublayer:pointerSyncLayer];
  }
  
  pointerSyncLayer.frame = CGRectMake(0.0f, 0.0f, scrollView.contentSize.width, scrollView.contentSize.height);
  
  if (nil == pointerLayer) {
    pointerLayer = [[CALayer layer] retain];
    pointerLayer.backgroundColor = [[UIColor redColor] CGColor];
    [pointerSyncLayer addSublayer:pointerLayer];
  }
  
  pointerLayer.frame = CGRectMake(0.0f, 0.0f, 1.0f, scrollView.frame.size.height);
  
  [pointerLayer removeAnimationForKey:@"pointerAnimation"];
  pointerAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
  pointerAnimation.fromValue = [NSValue valueWithCGPoint:pointerLayer.position];
  pointerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(
    pointerSyncLayer.bounds.size.width,
    pointerSyncLayer.bounds.size.height / 2.0f
  )];
  pointerAnimation.removedOnCompletion = NO;
  pointerAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
  pointerAnimation.duration = CMTimeGetSeconds(self.playerItem.duration);
  [pointerLayer addAnimation:pointerAnimation forKey:@"pointerAnimation"];
}

- (void)setupSelectedRangeLayer {
  CGFloat selectionStartX = coordinateFromTime(self.selectedRange.start, _widthPerMinute);
  CGFloat selectionWidthX = coordinateFromTime(self.selectedRange.duration, _widthPerMinute);

  if (nil == rangeAdjustmentView) {
    rangeAdjustmentView = [[UIView alloc] initWithFrame:CGRectMake(selectionStartX,
      0.0f,
      selectionWidthX,
      scrollView.frame.size.height
    )];
    rangeAdjustmentView.backgroundColor = [UIColor blueColor];
    rangeAdjustmentView.alpha = 0.5f;
    [scrollView addSubview:rangeAdjustmentView];
    [scrollView.layer insertSublayer:pointerSyncLayer above:rangeAdjustmentView.layer];
  }
  
  rangeAdjustmentView.frame = CGRectMake(selectionStartX, 0.0f, selectionWidthX, scrollView.frame.size.height);
  
  if (nil == rangeAdjustmentStartImageView) {
    rangeAdjustmentStartImageView = [[UIImageView alloc]
      initWithImage:[UIImage imageNamed:@"audioRangeAdjustorTop.png"]];
    rangeAdjustmentStartImageView.frame = CGRectMake(
      coordinateFromTime(self.selectedRange.start, _widthPerMinute) - 17.0f,
      0.0f,
      34.0f,
      34.0f
    );
    rangeAdjustmentStartImageView.userInteractionEnabled = YES;
    rangeAdjustmentStartImageView.hidden = YES;
  
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc]
      initWithTarget:self
      action:@selector(adjustedRange:)];
    [rangeAdjustmentStartImageView addGestureRecognizer:panGestureRecognizer];
    [panGestureRecognizer release];

    [scrollView addSubview:rangeAdjustmentStartImageView];
  } else {
    rangeAdjustmentStartImageView.center = CGPointMake(
      coordinateFromTime(self.selectedRange.start, _widthPerMinute),
      rangeAdjustmentStartImageView.center.y
    );
  }
  
  if (nil == rangeAdjustmentEndImageView) {
    rangeAdjustmentEndImageView = [[UIImageView alloc]
      initWithImage:[UIImage imageNamed:@"audioRangeAdjustorBottom.png"]];
    rangeAdjustmentEndImageView.frame = CGRectMake(
      coordinateFromTime(CMTimeRangeGetEnd(self.selectedRange), _widthPerMinute) - 17.0f,
      scrollView.contentSize.height - 34.0f,
      34.0f,
      34.0f
    );
    rangeAdjustmentEndImageView.userInteractionEnabled = YES;
    rangeAdjustmentEndImageView.hidden = YES;
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc]
      initWithTarget:self
      action:@selector(adjustedRange:)];
    [rangeAdjustmentEndImageView addGestureRecognizer:panGestureRecognizer];
    [panGestureRecognizer release];

    [scrollView addSubview:rangeAdjustmentEndImageView];
  } else {
    rangeAdjustmentEndImageView.center = CGPointMake(
      coordinateFromTime(CMTimeRangeGetEnd(self.selectedRange), _widthPerMinute),
      rangeAdjustmentEndImageView.center.y);
  }
}

- (void)setupWaveformView {
  if (nil == waveformView) {
    waveformView = [[UPAudioWaveformView alloc]
      initWithFrame:CGRectMake(
        0.0f,
        0.0f,
        scrollView.contentSize.width,
        scrollView.contentSize.height
      )
      playerItem:self.playerItem];
    [scrollView addSubview:waveformView];
  }
  
  waveformView.frame = CGRectMake(
    0.0f,
    0.0f,
    scrollView.contentSize.width,
    scrollView.contentSize.height
  );
}

- (void)beginSelection {
  self.selecting = YES;
  
  [self setupSelectionRangeAnimation:self.selectedRange];

  rangeAdjustmentView.hidden = YES;

  rangeAdjustmentStartImageView.hidden = YES;
  rangeAdjustmentEndImageView.hidden = YES;
  self.selectedRange = CMTimeRangeMake(self.playerItem.currentTime, kCMTimeZero);
}

- (void)endSelection {
  self.selecting = NO;
  
  self.selectedRange = CMTimeRangeMake(
    self.selectedRange.start,
    CMTimeSubtract(
      self.playerItem.currentTime,
      self.selectedRange.start
    )
  );

  [rangeAnimationLayer removeAnimationForKey:@"rangeAnimation"];
  [rangeAnimationLayer removeFromSuperlayer];
  [rangeAnimationLayer release];
  rangeAnimationLayer = nil;
  
  [rangeSyncLayer removeFromSuperlayer];
  [rangeSyncLayer release];
  rangeSyncLayer = nil;

  rangeAdjustmentView.hidden = NO;
  
  rangeAdjustmentStartImageView.hidden = NO;
  rangeAdjustmentStartImageView.frame = CGRectMake(
    coordinateFromTime(self.selectedRange.start, _widthPerMinute) - 17.0f,
    0.0f,
    34.0f,
    34.0f
  );
  
  rangeAdjustmentEndImageView.hidden = NO;
  rangeAdjustmentEndImageView.frame = CGRectMake(
    coordinateFromTime(CMTimeRangeGetEnd(self.selectedRange), _widthPerMinute) - 17.0f,
    scrollView.contentSize.height - 34.0f,
    34.0f,
    34.0f
  );
}

- (void)adjustedRange:(UIGestureRecognizer*)gestureRecognizer {  
  CGPoint touchLocation = [gestureRecognizer locationInView:scrollView];

  if (gestureRecognizer.view == rangeAdjustmentStartImageView) {
    CMTime newStartTime = timeFromCoordinate(touchLocation.x, _widthPerMinute, preferredScale);
    CMTime endTime = CMTimeRangeGetEnd(self.selectedRange);
    
    if (CMTIME_COMPARE_INLINE(newStartTime, >=, endTime)) {
      endTime = newStartTime;
      rangeAdjustmentEndImageView.center = CGPointMake(touchLocation.x, rangeAdjustmentEndImageView.center.y);
    }
  
    rangeAdjustmentStartImageView.center = CGPointMake(touchLocation.x, rangeAdjustmentStartImageView.center.y);

    self.selectedRange = CMTimeRangeFromTimeToTime(newStartTime, endTime);
  } else if (gestureRecognizer.view == rangeAdjustmentEndImageView) {
    CMTime startTime = self.selectedRange.start;
    CMTime newEndTime = timeFromCoordinate(touchLocation.x, _widthPerMinute, preferredScale);
            
    if (CMTIME_COMPARE_INLINE(startTime, >=, newEndTime)) {
      startTime = newEndTime;
      rangeAdjustmentStartImageView.center = CGPointMake(touchLocation.x, rangeAdjustmentStartImageView.center.y);
    }
  
    rangeAdjustmentEndImageView.center = CGPointMake(touchLocation.x, rangeAdjustmentEndImageView.center.y);

    self.selectedRange = CMTimeRangeFromTimeToTime(startTime, newEndTime);
  }
  
  switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateBegan:
      self.adjusting = YES;
      [self sendActionsForControlEvents:UIControlEventTouchDown];
      break;
    case UIGestureRecognizerStateEnded:
      [self sendActionsForControlEvents:UIControlEventValueChanged|UIControlEventTouchUpInside];
      self.adjusting = NO;
      break;
    default:
      break;
  }  
}

#pragma mark - Gesture Recognizer
-(void)scrollViewLongPressed:(UIGestureRecognizer *)gesture {
  CGPoint touchLocation = [gesture locationInView:scrollView];
    
  switch (gesture.state) {
    case UIGestureRecognizerStateBegan:
      [self.playerItem seekToTime:timeFromCoordinate(
        touchLocation.x,
        _widthPerMinute,
        preferredScale
      )];
      [self sendActionsForControlEvents:UIControlEventTouchDown];
      break;
    case UIGestureRecognizerStateChanged:
      [self.playerItem seekToTime:timeFromCoordinate(
        touchLocation.x,
        _widthPerMinute,
        preferredScale
      )];
      [self sendActionsForControlEvents:UIControlEventTouchDragInside];
      break;
    case UIGestureRecognizerStateEnded:
      [self.playerItem seekToTime:timeFromCoordinate(
        touchLocation.x,
        _widthPerMinute,
        preferredScale
      )];
      [self sendActionsForControlEvents:UIControlEventValueChanged|UIControlEventTouchUpInside];
      break;
    default:
      break;
  }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
  return ![touch.view isDescendantOfView:rangeAdjustmentStartImageView] &&
    ![touch.view isDescendantOfView:rangeAdjustmentEndImageView];
}

- (void)pinch:(UIPinchGestureRecognizer*)recognizer {
  NSUInteger minutes = minutesFromDuration(self.playerItem.duration);
  CGFloat remainingPercentageOfAMinute = (CMTimeGetSeconds(self.playerItem.duration) - minutes * 60.0f) / 60.0f;
  CGFloat remainingWidth = remainingPercentageOfAMinute * _widthPerMinute;
  CGFloat totalWidth = _widthPerMinute * minutes + remainingWidth;

  switch (recognizer.state) {
    case UIGestureRecognizerStateBegan:
      startingWidthPerMinute = _widthPerMinute;
      startingContentWidth = scrollView.contentSize.width;
      startingTouchLocationAsPercent = [recognizer locationInView:scrollView].x / startingContentWidth;
      startingContentOffsetX = scrollView.contentOffset.x;
      break;
    case UIGestureRecognizerStateChanged:
      _widthPerMinute =  MAX(
        MIN(
          startingWidthPerMinute * recognizer.scale,
          30.0 * 60.0f / CMTimeGetSeconds(self.playerItem.duration) * self.bounds.size.width
        ),
        60.0f / CMTimeGetSeconds(self.playerItem.duration) * self.bounds.size.width
      );
      scrollView.contentOffset = CGPointMake(
        startingContentOffsetX + (totalWidth - startingContentWidth) * startingTouchLocationAsPercent,
        scrollView.contentOffset.y);
      break;
    case UIGestureRecognizerStateEnded:
      _widthPerMinute =  MAX(
        MIN(
          startingWidthPerMinute * recognizer.scale,
          30.0 * 60.0f / CMTimeGetSeconds(self.playerItem.duration) * self.bounds.size.width
        ),
        60.0f / CMTimeGetSeconds(self.playerItem.duration) * self.bounds.size.width
      );
      scrollView.contentOffset = CGPointMake(
        startingContentOffsetX + (totalWidth - startingContentWidth) * startingTouchLocationAsPercent,
        scrollView.contentOffset.y);
      [waveformView setNeedsDisplay];
      break;
    default:
      break;
  }
  
  [self setNeedsLayout];  
}

#pragma mark - Internal methods
-(void)loadScrollview:(CGFloat)widthPerMinute {
  NSUInteger i;
  NSUInteger minutes = minutesFromDuration(self.playerItem.duration);
  CGFloat remainingPercentageOfAMinute = (CMTimeGetSeconds(self.playerItem.duration) - minutes * 60.0f) / 60.0f;
  CGFloat remainingWidth = remainingPercentageOfAMinute * _widthPerMinute;
    
  for (i = 0; i < minutes; i++) {
    UPTimelineMinuteView *currentMinuteView = [self minuteViewWithMinute:i width:_widthPerMinute];
    
    if (nil == currentMinuteView.superview) {
      [scrollView addSubview:currentMinuteView];
      [scrollView sendSubviewToBack:currentMinuteView];
    }
  }
  
  UPTimelineMinuteView *lastMinuteView = [self minuteViewWithMinute:i width:remainingWidth];

  if (nil == lastMinuteView.superview) {
    [scrollView addSubview:lastMinuteView];
    [scrollView sendSubviewToBack:lastMinuteView];
  }

  scrollView.contentSize = CGSizeMake(_widthPerMinute * minutes + remainingWidth, self.bounds.size.height);
}

-(UPTimelineMinuteView*)minuteViewWithMinute:(NSUInteger)currentMinute width:(CGFloat)width {
  UPTimelineMinuteView *minuteView = (UPTimelineMinuteView*) [scrollView viewWithTag:currentMinute+1];

  if (nil == minuteView) {
    minuteView = [[[UPTimelineMinuteView alloc]
      initWithMinute:currentMinute
      size:CGSizeMake(width, self.bounds.size.height)
      widthPerMinute:_widthPerMinute] autorelease];
        
    minuteView.backgroundColor = [UIColor clearColor];
    minuteView.tag = currentMinute + 1;
  } else {
    [minuteView updateWithSize:CGSizeMake(width, self.bounds.size.height) widthPerMinute:_widthPerMinute];
  }

  return minuteView;
}

@end
