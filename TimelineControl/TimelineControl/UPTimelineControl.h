//
//  CCVTimelineView.h
//  Chat
//
//  Created by Matthew Gillingham on 11/25/11.
//  Copyright (c) 2011 Matt Gillingham. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import "UPAudioWaveformView.h"

@interface UPTimelineControl : UIControl <UIGestureRecognizerDelegate> {
  UIScrollView *scrollView;
    
  AVSynchronizedLayer *pointerSyncLayer;
  CALayer *pointerLayer;
  CABasicAnimation *pointerAnimation;
  
  AVSynchronizedLayer *rangeSyncLayer;
  CALayer *rangeAnimationLayer;
  CABasicAnimation *rangeAnimation;
  
  UIView *rangeAdjustmentView;
  UIImageView *rangeAdjustmentStartImageView;
  UIImageView *rangeAdjustmentEndImageView;
  
  uint32_t preferredScale;
  CGFloat startingWidthPerMinute;
  CGFloat startingContentWidth;
  CGFloat startingTouchLocationAsPercent;
  CGFloat startingContentOffsetX;
  
  UPAudioWaveformView *waveformView;
}

@property (nonatomic, assign) AVPlayerItem *playerItem;
@property (nonatomic) CMTimeRange selectedRange;
@property (nonatomic) CGFloat widthPerMinute;
@property BOOL selecting;
@property BOOL adjusting;

- (void)beginSelection;
- (void)endSelection;

@end
