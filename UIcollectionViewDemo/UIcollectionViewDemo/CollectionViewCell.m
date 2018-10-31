//
//  CollectionViewCell.m
//  UIcollectionViewDemo
//
//  Created by 朱昱丰 on 2018/10/29.
//  Copyright © 2018年 Tony. All rights reserved.
//

#import "CollectionViewCell.h"

@interface CollectionViewCell ()

@property (nonatomic, strong) UILabel *label;

@end

@implementation CollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initUI];
    }
    return self;
}

- (void)initUI {
    self.contentView.backgroundColor = [UIColor whiteColor];
    
    [self.layer setBorderWidth:3.0];
    [self.layer setBorderColor:[UIColor greenColor].CGColor];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 40, 40)];
    self.label = label;
    label.textColor = [UIColor blackColor];
    label.font = [UIFont systemFontOfSize:20];
    
    [self.contentView addSubview:label];
}

- (void)setNumber:(NSNumber *)number {
    _number = number;
    self.label.text = [NSString stringWithFormat:@"%@",number];
}

@end
