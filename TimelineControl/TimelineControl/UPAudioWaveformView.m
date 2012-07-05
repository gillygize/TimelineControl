//
//  UPAudioWaveformView.m
//  TimelineControl
//
//  Created by Matthew Gillingham on 2/20/12.
//  Copyright (c) 2012 Matt Gillingham. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "UPAudioWaveformView.h"

@interface UPAudioWaveformView ()
- (void)loadAudioData:(AVPlayerItem*)playerItem;
@end

@implementation UPAudioWaveformView

+ layerClass
{
  return [CATiledLayer class];
}

- (id)initWithFrame:(CGRect)frame playerItem:(AVPlayerItem*)playerItem {
  if (self = [super initWithFrame:frame]){
    audioData = [[NSMutableData alloc] init];

    [self loadAudioData:playerItem];
    sampleCount = audioData.length / 2;
    self.backgroundColor = [UIColor clearColor];    
    
    CATiledLayer *tiledLayer = (CATiledLayer*)self.layer;
    tiledLayer.tileSize = CGSizeMake(512.0, 512.0);

  }
  return self;
}

- (void)dealloc {
  [audioData release];
  [super dealloc];
}

- (void)drawRect:(CGRect)rect {
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
  SInt16 *samples = (SInt16 *) audioData.bytes;

  CGContextSetAlpha(ctx, 0.3f);
  CGContextSetLineWidth(ctx, 1.0);

  CGFloat halfGraphHeight = (self.bounds.size.height / 2);
  CGFloat sampleAdjustmentFactor = (self.bounds.size.height / (CGFloat) channelCount) / (CGFloat) normalizeMax;

  for (NSInteger intSample = 0; intSample < sampleCount; intSample++) {
    SInt16 sample = *samples++;

    CGFloat pixels = sample * sampleAdjustmentFactor;
        
    CGFloat samplePercent = (intSample * 1.0f) / sampleCount;
    CGFloat xPosition = self.bounds.size.width * samplePercent;
                
    CGContextMoveToPoint(ctx, xPosition, halfGraphHeight-pixels);
    CGContextAddLineToPoint(ctx, xPosition, halfGraphHeight+pixels);
    CGContextSetStrokeColorWithColor(ctx, [[UIColor blackColor] CGColor]);
    CGContextStrokePath(ctx);
  }
}

- (void)loadAudioData:(AVPlayerItem *)playerItem {
  NSError * error = nil;

  AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:playerItem.asset error:&error];
  AVAssetTrack *songTrack = [playerItem.asset.tracks objectAtIndex:0];

  NSDictionary *outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved, nil];

  AVAssetReaderTrackOutput* output = [[AVAssetReaderTrackOutput alloc]
    initWithTrack:songTrack
    outputSettings:outputSettingsDict];
    
  [reader addOutput:output];
  
  [outputSettingsDict release];
  [output release];

  NSInteger samplesPerPixel = 0;

  NSArray* formatDesc = songTrack.formatDescriptions;
  
  for(unsigned int i = 0; i < [formatDesc count]; ++i) {
    CMAudioFormatDescriptionRef item = (CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
    const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription (item);
        
    if(fmtDesc) {
      UInt32 sampleRate = fmtDesc->mSampleRate;
      channelCount = fmtDesc->mChannelsPerFrame;
      samplesPerPixel = sampleRate / 50;
    }
  }

  UInt32 bytesPerSample = 2 * channelCount;
  normalizeMax = 0;

  [reader startReading];
  
  UInt64 totalBytes = 0; 

  SInt64 totalLeft = 0;
  SInt64 totalRight = 0;
  NSInteger sampleTally = 0;


  while (reader.status == AVAssetReaderStatusReading) {
    AVAssetReaderTrackOutput *trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
    CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];

    if (sampleBufferRef){
      CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);

      size_t length = CMBlockBufferGetDataLength(blockBufferRef);
      totalBytes += length;
      
      @autoreleasepool {
        NSMutableData *data = [NSMutableData dataWithLength:length];
        CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, data.mutableBytes);

        SInt16 *samples = (SInt16 *) data.mutableBytes;
        int currentSampleCount = length / bytesPerSample;
        
        for (int i = 0; i < currentSampleCount ; i ++) {
          SInt16 left = *samples++;
          totalLeft += left;

          SInt16 right;
          if (channelCount==2) {
            right = *samples++;
            totalRight += right;
          }

          sampleTally++;

          if (sampleTally > samplesPerPixel) {
            SInt16 average;
          
            left = totalLeft / sampleTally; 

            SInt16 fix = abs(left);
            if (fix > normalizeMax) {
              normalizeMax = fix;
            }
            
            average = left;

            if (channelCount == 2) {
              right = totalRight / sampleTally; 

              SInt16 fix = abs(right);
              if (fix > normalizeMax) {
                normalizeMax = fix;
              }
              
              average = (left + right) / 2;
            }
            
            [audioData appendBytes:&average length:sizeof(average)];

            totalLeft   = 0;
            totalRight  = 0;
            sampleTally = 0;

          }
        }
      }

      CMSampleBufferInvalidate(sampleBufferRef);
      CFRelease(sampleBufferRef);
    }
  }

  if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown){
    // Something went wrong. return nil
  }
  
  [reader release];

}

@end
