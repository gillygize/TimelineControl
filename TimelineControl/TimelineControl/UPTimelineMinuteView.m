//
//  CCVTimeLineTableViewCell.m
//  Chat
//
//  Created by Matthew Gillingham on 11/25/11.
//  Copyright (c) 2011 Matt Gillingham. All rights reserved.
//

#import "UPTimeLineMinuteView.h"

@implementation UPTimelineMinuteView

@synthesize minute = _minute;
@synthesize size = _size;
@synthesize widthPerMinute = _widthPerMinute;

-(id)initWithMinute:(NSUInteger)aMinute size:(CGSize)aSize widthPerMinute:(CGFloat)widthPerMinute {
  if ((self = [super initWithFrame:CGRectMake(aMinute * widthPerMinute, 0.0f, aSize.width, aSize.height)])) {
    _minute = aMinute;
    _size = aSize;
    _widthPerMinute = widthPerMinute;
    
    timelineMarkerImage = [[UIImage imageNamed:@"timeline-line.png"] retain];
      
    NSString *timeString = [NSString stringWithFormat:@"%d:00", _minute];
    UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:10.0f];
      
    CGSize timeLabelSize = [timeString sizeWithFont:font];
    timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(
      -timeLabelSize.width / 2.0f + timelineMarkerImage.size.width / 2.0f,
      aSize.height / 2.0f + timelineMarkerImage.size.height / 2.0f,
      timeLabelSize.width,
      timeLabelSize.height
    )];
    
    timeLabel.textColor = [UIColor darkGrayColor];
    timeLabel.font = font;
    timeLabel.backgroundColor = [UIColor clearColor];
    timeLabel.text = timeString;
    [self addSubview:timeLabel];
  }
    
  return self;
}

- (void)updateWithSize:(CGSize)size widthPerMinute:(CGFloat)widthPerMinute {
  self.widthPerMinute = widthPerMinute;
  self.size = size;
  self.frame = CGRectMake(self.minute * self.widthPerMinute, 0.0f, self.size.width, self.size.height);
  
  [self setNeedsDisplay];
}

-(void)dealloc {
  [timelineMarkerImage release];
  [timeLabel release];
  [super dealloc];
}

- (void)drawRect:(CGRect)rect
{    
  CGPoint markerDrawingPoint = CGPointMake(
    0.0f,
    self.frame.size.height / 2.0f - timelineMarkerImage.size.height / 2.0f
  );
    
  [timelineMarkerImage drawAtPoint:markerDrawingPoint];
    
  UIImage *timelineTickerImage = [UIImage imageNamed:@"timeline-ticker.png"];
  NSUInteger numberOfDivisions = 4;
    
  for (int i = 1; i < numberOfDivisions; i++) {
    CGFloat divisionSize = _widthPerMinute / numberOfDivisions;
    CGPoint tickerDrawingPoint = CGPointMake(
      i * divisionSize,
      self.frame.size.height / 2.0f - timelineTickerImage.size.height / 2.0f
    );
    
    [timelineTickerImage drawAtPoint:tickerDrawingPoint];
  }
        
  [timelineMarkerImage drawAtPoint:markerDrawingPoint];
}


@end