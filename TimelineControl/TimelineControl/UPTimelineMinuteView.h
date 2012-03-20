//
//  CCVTimeLineTableViewCell.h
//  Chat
//
//  Created by Matthew Gillingham on 11/25/11.
//  Copyright (c) 2011 Matt Gillingham. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UPTimelineMinuteView : UIView {
    UILabel *timeLabel;
    UIImage *timelineMarkerImage;
}

@property (nonatomic) NSUInteger minute;
@property (nonatomic) CGSize size;
@property (nonatomic) CGFloat widthPerMinute;

- (id)initWithMinute:(NSUInteger)aMinute size:(CGSize)aSize widthPerMinute:(CGFloat)widthPerMinute;
- (void)updateWithSize:(CGSize)size widthPerMinute:(CGFloat)widthPerMinute;

@end
