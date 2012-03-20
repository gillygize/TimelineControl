//
//  UPAudioWaveformView.h
//  TimelineControl
//
//  Created by Matthew Gillingham on 2/20/12.
//  Copyright (c) 2012 Matt Gillingham. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UPAudioWaveformView : UIView {
  NSMutableData *audioData;
  SInt16 normalizeMax;
  NSInteger sampleCount;
  NSInteger channelCount;
}

-(id)initWithFrame:(CGRect)frame playerItem:(AVPlayerItem*)playerItem;

@end
