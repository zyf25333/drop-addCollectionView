//
//  ViewController.m
//  UIcollectionViewDemo
//
//  Created by 朱昱丰 on 2018/10/29.
//  Copyright © 2018年 Tony. All rights reserved.
//

#import "ViewController.h"
#import "CollectionViewCell.h"

static NSString *identity = @"CollectionViewCell";

#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)

typedef NS_ENUM(NSUInteger, cellScrollDirection) {
    cellScrollDirectionNone = 0,
    cellScrollDirectionLeft,
    cellScrollDirectionRight,
    cellScrollDirectionUp,
    cellScrollDirectionDown
};

@interface ViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *dataArray;

//随手指拖动的cell
@property (nonatomic, strong) NSIndexPath *originalIndexPath;
@property (nonatomic, weak) UICollectionViewCell *orignalCell;
@property (nonatomic, assign) CGPoint orignalCenter;

//手指拖动的控件
@property (nonatomic, weak) UIView *tempMoveCell;

//移动操作计时器
@property (nonatomic, strong) NSTimer *moveTimer;
//滚动计时器
@property (nonatomic, strong) CADisplayLink *edgeTimer;
//添加操作计时器
@property (nonatomic, strong) NSTimer *addTimer;

//添加相关控件
@property (nonatomic, weak) UICollectionViewCell *motherCell;
@property (nonatomic, weak) UIView *bigMotherCell;

//移动相关控件
@property (nonatomic, strong) NSIndexPath *moveIndexPath;
@property (nonatomic, strong) UICollectionViewCell *willMoveCell;

//滚动相关数据
@property (nonatomic, assign) cellScrollDirection scrollDirection;
@property (nonatomic, assign) CGPoint lastPoint;

@end

@implementation ViewController

- (NSMutableArray *)dataArray {
    if (!_dataArray) {
        _dataArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < 40; i ++) {
            [_dataArray addObject:[NSNumber numberWithInt:i]];
        }
    }
    return _dataArray;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initUI];
}

- (void)initUI {
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT) collectionViewLayout:flowLayout];
    self.collectionView = collectionView;
    [self.view addSubview:collectionView];
    
    collectionView.delegate = self;
    collectionView.dataSource = self;
    [collectionView registerClass:[CollectionViewCell class] forCellWithReuseIdentifier:identity];
    collectionView.alwaysBounceVertical = YES;
    
    UILongPressGestureRecognizer *longGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongGesture:)];
    [collectionView addGestureRecognizer:longGesture];
}

#pragma mark - 手势
- (void)handleLongGesture:(UILongPressGestureRecognizer *)longGesture {
    switch (longGesture.state) {
        case UIGestureRecognizerStateBegan:
            [self gestureBegan:longGesture];
            break;
        case UIGestureRecognizerStateChanged:
            [self gestureChange:longGesture];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            [self gestureEndOrCancle:longGesture];
            break;
        default:

            break;
    }
}

- (void)gestureBegan:(UILongPressGestureRecognizer *)longPressGesture {
    
    self.originalIndexPath = [self.collectionView indexPathForItemAtPoint:[longPressGesture locationOfTouch:0 inView:longPressGesture.view]];
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:self.originalIndexPath];//拿到被长按的格子
    
    //下面这一片是对这个格子截图
    UIImage *snap;
    UIGraphicsBeginImageContextWithOptions(cell.bounds.size, 1.0f, 0);
    [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
    snap = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //把截好的图片装进一个假的View里，之后用这个View随手指拖动而运动而隐藏原格子，给用户造成其实是格子被拖动的效果
    UIView *tempMoveCell = [UIView new];
    tempMoveCell.layer.contents = (__bridge id)snap.CGImage;
    cell.hidden = YES;
    
    self.orignalCell = cell;
    self.orignalCenter = cell.center;
    
    self.tempMoveCell = tempMoveCell;
    self.tempMoveCell.frame = cell.frame;
    [self.collectionView addSubview:self.tempMoveCell];
    //开启边缘滚动定时器
    [self setEdgeTimer];
    //开启抖动
    [self itemshake];
    self.lastPoint = [longPressGesture locationOfTouch:0 inView:longPressGesture.view];
}

- (void)gestureChange:(UILongPressGestureRecognizer *)longPressGesture {
    CGFloat tranX = [longPressGesture locationOfTouch:0 inView:longPressGesture.view].x - self.lastPoint.x;
    CGFloat tranY = [longPressGesture locationOfTouch:0 inView:longPressGesture.view].y - self.lastPoint.y;
    self.tempMoveCell.center = CGPointApplyAffineTransform(self.tempMoveCell.center, CGAffineTransformMakeTranslation(tranX, tranY));
    //让你的假格子View随手指移动
    self.lastPoint = [longPressGesture locationOfTouch:0 inView:longPressGesture.view];
    [self handleCell];
}

- (void)gestureEndOrCancle:(UILongPressGestureRecognizer *)longPressGesture {
    self.collectionView.userInteractionEnabled = NO;
    [self stopEdgeTimer];
    if (self.motherCell) {
        [self stopAddToCellWithData:YES];
        [self removeTempMoveCell];
    } else {
        [UIView animateWithDuration:0.25 animations:^{
            self.tempMoveCell.center = self.orignalCenter;
        } completion:^(BOOL finished) {
            [self removeTempMoveCell];
        }];
    }
}

- (void)removeTempMoveCell {
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:self.originalIndexPath];
    [self.tempMoveCell removeFromSuperview];
    cell.hidden = NO;
    self.orignalCell.hidden = NO;
    self.collectionView.userInteractionEnabled = YES;
    self.originalIndexPath = nil;
}

#pragma mark - 动画
- (void)itemshake {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    [animation setDuration:0.1];
    animation.fromValue = @(-M_1_PI/6);
    animation.toValue = @(M_1_PI/6);
    animation.repeatCount = 1;
    animation.autoreverses = YES;
    self.tempMoveCell.layer.anchorPoint = CGPointMake(0.5, 0.5);
    [self.tempMoveCell.layer addAnimation:animation forKey:@"rotation"];
}

#pragma mark - 操作
#define MoveSpace 20    //在格子里的这么大范围内也算move操作的触发点，而不是add操作的触发点
- (void)handleCell {
    for (UICollectionViewCell *cell in [self.collectionView visibleCells]) {//遍历所有的可视cell
        if ([self.collectionView indexPathForCell:cell] == _originalIndexPath) {//如果是自己这个cell，那么跳过
            continue;
        }
        //计算所有表格中心和在移动的格子中心的距离
        CGFloat spacingX = fabs(self.tempMoveCell.center.x - cell.center.x);
        CGFloat spacingY = fabs(_tempMoveCell.center.y - cell.center.y);
        
        if (self.motherCell == cell) {
            if (spacingX > _tempMoveCell.bounds.size.width / 2.0f - MoveSpace || spacingY > _tempMoveCell.bounds.size.height / 2.0f - MoveSpace) {
                //跑出了格子
                [self stopAddToCellWithData:NO];
            }
        }
        if (spacingX <= _tempMoveCell.bounds.size.width / 2.0f - MoveSpace && spacingY <= _tempMoveCell.bounds.size.height / 2.0f - MoveSpace) {
//            NSLog(@"进入格子内");
            self.motherCell = cell;
            [self setAddTimer];
            self.moveIndexPath = [self.collectionView indexPathForCell:cell];
        } else if (spacingX >= _tempMoveCell.bounds.size.width / 2.0f  - MoveSpace && spacingX <= _tempMoveCell.bounds.size.width / 2.0f + 7.5  && spacingY <= _tempMoveCell.bounds.size.height / 2.0f - MoveSpace) {
            //移动
            self.willMoveCell = cell;
            [self setMoveTimer];
            break;
        }
    }
}


#pragma mark - 移动
- (void)moveCell {
    NSLog(@"%@", [self.collectionView cellForItemAtIndexPath:self.originalIndexPath]);
    self.moveIndexPath = [self.collectionView indexPathForCell:self.willMoveCell];
    self.orignalCell = self.willMoveCell;
    NSLog(@"handleCell赋值，cell编号为%@",((CollectionViewCell *)self.willMoveCell).number);
    self.orignalCenter = self.willMoveCell.center;
    [CATransaction begin];
    [self.collectionView moveItemAtIndexPath:self.originalIndexPath toIndexPath:self.moveIndexPath];
    [CATransaction setCompletionBlock:^{
        //                NSLog(@"动画完成");
        [self stopMoveTimer];
        
    }];
    [CATransaction commit];
    self.originalIndexPath = self.moveIndexPath;
}

#pragma mark - 添加
- (void)addToCell {
//    NSLog(@"开始add操作");
    if (self.motherCell) {
//        NSLog(@"开始放大");
        //跟上面一样，对添加操作作为文件夹一方的格子（motherCell）进行截图
        UIImage *snap;
        UIGraphicsBeginImageContextWithOptions(self.motherCell.bounds.size, 1.0f, 0);
        [self.motherCell.layer renderInContext:UIGraphicsGetCurrentContext()];
        snap = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        //把截图装进一个假的View里
        UIView *bigMotherCell = [UIView new];
        bigMotherCell.layer.contents = (__bridge id)snap.CGImage;
//        self.motherCell.hidden = YES;
        
        self.bigMotherCell = bigMotherCell;
        self.bigMotherCell.frame = self.motherCell.frame;
        [self.collectionView addSubview:self.bigMotherCell];
        CGRect rect = self.bigMotherCell.frame;
        CGFloat scale = 1.3;
        [self.collectionView bringSubviewToFront:self.tempMoveCell];
        
        //方法这个假View，造成文件夹要容纳文件的效果
        [UIView animateWithDuration:0.5 animations:^{
            self.bigMotherCell.frame = CGRectMake(rect.origin.x - rect.size.width * (scale - 1)/2, rect.origin.y - rect.size.height * (scale - 1)/2, rect.size.width * scale, rect.size.height * scale);
        } completion:nil];
    } else {
//        NSLog(@"没有motherCell");
    }
}

- (void)stopAddToCellWithData:(BOOL)withData {
    if (self.motherCell) {
        [UIView animateWithDuration:0.1 animations:^{
            self.bigMotherCell.frame = self.motherCell.frame;
            if (withData) {
                //        NSIndexPath *motherIndexPath = [self.collectionView indexPathForCell:self.motherCell];
                        NSIndexPath *childIndexPath = [self.collectionView indexPathForCell:self.orignalCell];
                NSLog(@"把编号为%@的格子移动到编号为%@的格子里",((CollectionViewCell *)self.orignalCell).number, ((CollectionViewCell *)self.motherCell).number);
                [self.dataArray removeObjectAtIndex:childIndexPath.row];
                [self.collectionView deleteItemsAtIndexPaths:@[childIndexPath]];
            }
        } completion:^(BOOL finished) {
            [self.bigMotherCell removeFromSuperview];
            self.motherCell = nil;
            [self stopAddTimer];
        }];
    }
}

#pragma mark - 滚动

- (void)edgeScroll {
    [self setScrollDirection];
    switch (self.scrollDirection) {
        case cellScrollDirectionLeft:{
            //这里的动画必须设为NO
            [self.collectionView setContentOffset:CGPointMake(self.collectionView.contentOffset.x - 4, self.collectionView.contentOffset.y) animated:NO];
            self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x - 4, self.tempMoveCell.center.y);
            _lastPoint.x -= 4;
        }
            break;
        case cellScrollDirectionRight:{
            [self.collectionView setContentOffset:CGPointMake(self.collectionView.contentOffset.x + 4, self.collectionView.contentOffset.y) animated:NO];
            self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x + 4, self.tempMoveCell.center.y);
            _lastPoint.x += 4;
        }
            break;
        case cellScrollDirectionUp:{
            [self.collectionView setContentOffset:CGPointMake(self.collectionView.contentOffset.x, self.collectionView.contentOffset.y - 4) animated:NO];
            self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x, self.tempMoveCell.center.y - 4);
            _lastPoint.y -= 4;
        }
            break;
        case cellScrollDirectionDown:{
            [self.collectionView setContentOffset:CGPointMake(self.collectionView.contentOffset.x, self.collectionView.contentOffset.y + 4) animated:NO];
            self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x, self.tempMoveCell.center.y + 4);
            _lastPoint.y += 4;
        }
            break;
        default:
            break;
    }
}

- (void)setScrollDirection {
    self.scrollDirection = cellScrollDirectionNone;
    if (self.collectionView.bounds.size.height + self.collectionView.contentOffset.y - self.tempMoveCell.center.y < self.tempMoveCell.bounds.size.height / 2 && self.collectionView.bounds.size.height + self.collectionView.contentOffset.y < self.collectionView.contentSize.height) {
        self.scrollDirection = cellScrollDirectionDown;
    }
    if (self.tempMoveCell.center.y - self.collectionView.contentOffset.y < self.tempMoveCell.bounds.size.height / 2 && self.collectionView.contentOffset.y > 0) {
        self.scrollDirection = cellScrollDirectionUp;
    }
    if (self.collectionView.bounds.size.width + self.collectionView.contentOffset.x - self.tempMoveCell.center.x < self.tempMoveCell.bounds.size.width / 2 && self.collectionView.bounds.size.width + self.collectionView.contentOffset.x < self.collectionView.contentSize.width) {
        self.scrollDirection = cellScrollDirectionRight;
    }
    if (self.tempMoveCell.center.x - self.collectionView.contentOffset.x < self.tempMoveCell.bounds.size.width / 2 && self.collectionView.contentOffset.x > 0) {
        self.scrollDirection = cellScrollDirectionLeft;
    }
}

#pragma mark - 计时器

- (void)setEdgeTimer {
    if (!_edgeTimer) {
        _edgeTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(edgeScroll)];
        [_edgeTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)stopEdgeTimer {
    if (_edgeTimer) {
        [_edgeTimer invalidate];
        _edgeTimer = nil;
    }
}

- (void)setAddTimer {
    if (!_addTimer) {
        [self stopMoveTimer];
        //        NSLog(@"新建timer");
        _addTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(addToCell) userInfo:nil repeats:NO];
    }
}

- (void)stopAddTimer {
    if (_addTimer) {
        //        NSLog(@"销毁timer");
        [_addTimer invalidate];
        _addTimer = nil;
    }
}

- (void)setMoveTimer {
    if (!_moveTimer) {
        [self stopAddTimer];
        //        NSLog(@"新建timer");
        _moveTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(moveCell) userInfo:nil repeats:NO];
    }
}

- (void)stopMoveTimer {
    if (_moveTimer) {
        //        NSLog(@"销毁timer");
        [_moveTimer invalidate];
        _moveTimer = nil;
    }
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identity forIndexPath:indexPath];
    cell.number = self.dataArray[indexPath.row];
    return cell;
}

#pragma mark - UICollectionViewDelegate
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake((SCREEN_WIDTH - 60) / 3, 130);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 15;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 15;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
        return UIEdgeInsetsMake(15, 15, 15, 15);
}




@end
