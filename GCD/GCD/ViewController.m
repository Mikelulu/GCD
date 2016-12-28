//
//  ViewController.m
//  GCD
//
//  Created by Mike on 2016/12/28.
//  Copyright © 2016年 LK. All rights reserved.
//

/*
 NSThread (抽象层次：低)
 优点：轻量级，简单易用，可以直接操作线程对象
 缺点: 需要自己管理线程的生命周期，线程同步。线程同步对数据的加锁会有一定的系统开销。
 
 Cocoa NSOperation (抽象层次：中)
 优点：不需要关心线程管理，数据同步的事情，可以把精力放在学要执行的操作上。基于GCD，是对GCD 的封装，比GCD更加面向对象
 缺点: NSOperation是个抽象类，使用它必须使用它的子类，可以实现它或者使用它定义好的两个子类NSInvocationOperation、NSBlockOperation.
 
 GCD 全称Grand Center Dispatch (抽象层次：高)
 优点：是 Apple 开发的一个多核编程的解决方法，简单易用，效率高，速度快，基于C语言，更底层更高效，并且不是Cocoa框架的一部分，自动管理线程生命周期（创建线程、调度任务、销毁线程）。
 缺点: 使用GCD的场景如果很复杂，就有非常大的可能遇到死锁问题。
*/
#import "ViewController.h"
#import <AFNetworking.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"GCD";
    self.view.backgroundColor = [UIColor whiteColor];
    
//    [self test17];
    [self getNetworkingData];
    
//    [self testSemaphore];
}
#pragma mark --The main queue(主线程串行队列)
/**
 获取主线程串行队列
 */
- (void)test1
{
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    NSLog(@"%@",[NSThread currentThread]);
}
/**
 主线程串行队列同步执行任务，在主线程运行时，会产生死锁
 */
- (void)test2
{
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_sync(mainQueue, ^{//同步
        NSLog(@"MainQueue");
    });
}
/**
 主线程串行队列异步执行任务，在主线程运行，不会产生死锁。
 */
- (void)test3
{
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_async(mainQueue, ^{//异步
       NSLog(@"%@",[NSThread currentThread]);
       NSLog(@"MainQueue");
    });
}

/**
 从子线程，异步返回主线程更新UI<这种使用方式比较多>
 */
- (void)test4
{
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);//第一个参数为优先级 第二个参数为0（官方文档介绍的）
    dispatch_async(globalQueue, ^{
        NSLog(@"子线程%@",[NSThread currentThread]);
        //子线程异步执行下载任务，防止主线程卡顿
        NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
        NSError *error;
        NSString *htmlData = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (htmlData != nil) {
            //异步返回主线程，根据获取的数据，更新UI
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"主线程%@",[NSThread currentThread]);
                NSLog(@"主线程更新UI");
            });
        }else{
            NSLog(@"error when download:%@",error);
        }
    });
}
#pragma mark --Global queue（全局并发队列)

/**
 获取全局并发队列
 */
- (void)test5
{
    //程序默认的队列级别，一般不要修改,DISPATCH_QUEUE_PRIORITY_DEFAULT == 0
    dispatch_queue_t globalQueue1 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    //HIGH
    dispatch_queue_t globalQueue2 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    //LOW
    dispatch_queue_t globalQueue3 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    //BACKGROUND
    dispatch_queue_t globalQueue4 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
}

/**
 全局并发队列同步执行任务，在主线程执行会导致页面卡顿。
 */
- (void)test6
{
    NSLog(@"current task");
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{//同步
        sleep(2.0);
        NSLog(@"sleep 2.0s");
    });
    NSLog(@"next task");//2s钟之后，才会执行block代码段下面的代码。
}

/**
 全局并发队列异步执行任务，在主线程运行，会开启新的子线程去执行任务，页面不会卡顿。
 */
- (void)test7
{
    NSLog(@"current task");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{//异步
        sleep(2.0);
        NSLog(@"sleep 2.0s");
    });
     NSLog(@"next task");//主线程不用等待2s钟，继续执行block代码段后面的代码。
}

/**
 多个全局并发队列，异步执行任务。
 */
- (void)test8
{
    NSLog(@"current task");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"最先加入全局并发队列");
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         NSLog(@"次加入全局并发队列");
    });
    NSLog(@"next task");
    /*
     异步线程的执行顺序是不确定的。几乎同步开始执行
     全局并发队列由系统默认生成的，所以无法调用dispatch_resume()和dispatch_suspend()来控制执行继续或中断。
     */
}
#pragma mark --Custom queue (自定义队列)
#pragma mark --自定义串行队列

/**
 获取自定义串行队列
 */
- (void)test9
{
    /*
     dispatch_queue_create(const char *label, dispatch_queue_attr_t attr)函数中第一个参数是给这个queue起的标识，这个在调试的可以看到是哪个队列在执行，或者在crash日志中，也能做为提示。第二个是需要创建的队列类型，是串行的还是并发的
     */
    dispatch_queue_t serialQueue = dispatch_queue_create("com.serialQueue", DISPATCH_QUEUE_SERIAL);
    NSLog(@"%s",dispatch_queue_get_label(serialQueue));
}

/**
 自定义串行队列同步执行任务
 */
- (void)test10
{
    NSLog(@"current task");
    dispatch_sync(dispatch_queue_create("com.serialQueue", DISPATCH_QUEUE_SERIAL), ^{
        NSLog(@"最先加入自定义串行队列");
        sleep(2);
    });
    dispatch_sync(dispatch_queue_create("com.serialQueue", DISPATCH_QUEUE_SERIAL), ^{
        NSLog(@"次加入自定义串行队列");
    });
    NSLog(@"next task");
    /*
     当前线程等待串行队列中的子线程执行完成之后再执行，串行队列中先进来的子线程先执行任务，执行完成后，再执行队列中后面的任务。
     */
}

/**
 自定义串行队列嵌套执行同步任务，产生死锁
 */
- (void)test11
{
    dispatch_queue_t serialQueue = dispatch_queue_create("com.dullgrass.serialQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_sync(serialQueue, ^{ //该代码段后面的代码都不会执行，程序被锁定在这里
        NSLog(@"会执行的代码");
        dispatch_sync(serialQueue, ^{
            NSLog(@"代码不执行");
        });
    });
}

/**
 异步执行串行队列，嵌套同步执行串行队列，同步执行的串行队列中的任务将不会被执行，其他程序正常执行
 */
- (void)test12
{
    dispatch_queue_t serialQueue = dispatch_queue_create("com.dullgrass.serialQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(serialQueue, ^{
        NSLog(@"会执行的代码");
        dispatch_sync(serialQueue, ^{
            NSLog(@"代码不执行");
        });
    });
}
#pragma mark --自定义并发队列
/**
 获取自定义并发队列
 */
- (void)test13
{
    dispatch_queue_t conCurrentQueue =   dispatch_queue_create("com.dullgrass.conCurrentQueue", DISPATCH_QUEUE_CONCURRENT);
    NSLog(@"%s",dispatch_queue_get_label(conCurrentQueue));
}

/**
 自定义并发队列执行同步任务
 */
- (void)test14
{
    dispatch_queue_t conCurrentQueue = dispatch_queue_create("com.dullgrass.conCurrentQueue", DISPATCH_QUEUE_CONCURRENT);
    NSLog(@"current task");
    dispatch_sync(conCurrentQueue, ^{
        NSLog(@"先加入队列");
    });
    dispatch_sync(conCurrentQueue, ^{
        NSLog(@"次加入队列");
    });
    NSLog(@"next task");
}

/**
 自定义并发队列嵌套执行同步任务（不会产生死锁，程序正常运行）
 */
- (void)test15
{
    dispatch_queue_t conCurrentQueue = dispatch_queue_create("com.dullgrass.conCurrentQueue", DISPATCH_QUEUE_CONCURRENT);
    NSLog(@"current task");
    dispatch_sync(conCurrentQueue, ^{
        NSLog(@"先加入队列");
        dispatch_sync(conCurrentQueue, ^{
            NSLog(@"次加入队列");
        });
    });
    NSLog(@"next task");
}

/**
 自定义并发队列执行异步任务
 */
- (void)test16
{
    dispatch_queue_t conCurrentQueue = dispatch_queue_create("com.dullgrass.conCurrentQueue", DISPATCH_QUEUE_CONCURRENT);
    NSLog(@"current task");
    dispatch_async(conCurrentQueue, ^{
        NSLog(@"先加入队列");
    });
    dispatch_async(conCurrentQueue, ^{
        NSLog(@"次加入队列");
    });
    NSLog(@"next task");
    /*
     异步执行任务，开启新的子线程，不影响当前线程任务的执行，并发队列中的任务，几乎是同步执行的，输出顺序不确定
     */
}
#pragma mark --Group queue (队列组)
/*
 当遇到需要执行多个线程并发执行，然后等多个线程都结束之后，再汇总执行结果时可以用group queue
 
 使用场景： 同时下载多个图片，所有图片下载完成之后去更新UI（需要回到主线程）或者去处理其他任务（可以是其他线程队列）。
 原理：使用函数dispatch_group_create创建dispatch group,然后使用函数dispatch_group_async来将要执行的block任务提交到一个dispatch queue。同时将他们添加到一个组，等要执行的block任务全部执行完成之后，使用dispatch_group_notify函数接收完成时的消息。
 */
- (void)test17
{
    NSLog(@"current task");
    // 第一个参数 添加到的队列组   第二个参数执行block的线程
   dispatch_group_async(dispatch_group_create(), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"并行任务1");
   });
   dispatch_group_async(dispatch_group_create(), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"并行任务2");
    });
    dispatch_group_notify(dispatch_group_create(), dispatch_get_main_queue(), ^{
         NSLog(@"groupQueue中的任务 都执行完成,回到主线程更新UI");
    });
    NSLog(@"next task");
}

/**
 同时获取两个网络请求的数据,但是网络请求是异步的,我们需要获取到两个网络请求的数据之后才能够进行下一步的操作,这个时候,就是线程组与信号量的用武之地了.
 */
- (void)getNetworkingData
{
    __block NSInteger count = 0;
    
    NSString *appIdKey = @"8781e4ef1c73ff20a180d3d7a42a8c04";
    NSString* urlString_1 = @"http://api.openweathermap.org/data/2.5/weather";
    NSString* urlString_2 = @"http://api.openweathermap.org/data/2.5/forecast/daily";
    NSDictionary* dictionary =@{@"lat":@"40.04991291",
                                @"lon":@"116.25626162",
                                @"APPID" : appIdKey};
    //创建队列组
    dispatch_group_t group = dispatch_group_create();
    //将第一个网络任务添加到队列组中
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        count = 1;
        //创建信号量
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        //开启网络请求任务
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        
        AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
        serializer.timeoutInterval = 5;
        manager.requestSerializer = serializer;
        
        [manager GET:urlString_1 parameters:dictionary progress:^(NSProgress * _Nonnull downloadProgress) {
            
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
//            NSLog(@"%@",[NSThread currentThread]);//主线程  seccess和failure都是在主线中异步任务中执行的。
            NSLog(@"成功请求数据1:%@",[responseObject class]);
            count = 2;
            
            // 如果请求成功，发送信号量
            dispatch_semaphore_signal(semaphore);
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
             NSLog(@"失败请求数据1");
            // 如果请求失败，也发送信号量
            dispatch_semaphore_signal(semaphore);
        }];
        // 在网络请求任务成功之前，信号量等待中
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
//        NSLog(@"%@",[NSThread currentThread]);
//        NSLog(@"第一个AFN网络请求框架请求完毕");
    });
    //将第二个网络请求任务添加到队列组中
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        count = 3;
        //创建信号量
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        //开启网络请求任务
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        
        AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
        serializer.timeoutInterval = 5;
        manager.requestSerializer = serializer;
        
        [manager GET:urlString_2 parameters:dictionary progress:^(NSProgress * _Nonnull downloadProgress) {
            
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
//            NSLog(@"%@",[NSThread currentThread]);
            NSLog(@"成功请求数据2:%@",[responseObject class]);
            count = 4;
            
            //如果请求成功 发送信号
            dispatch_semaphore_signal(semaphore);
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"失败请求数据2");
            
            // 如果请求失败，也发送信号量
            dispatch_semaphore_signal(semaphore);
        }];
        
        //在网络请求任务成功之前，信号量等待中
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
//        NSLog(@"%@",[NSThread currentThread]);
//        NSLog(@"第二个AFN网络请求框架请求完毕");
    });
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"完成了网络请求(不管网络请求失败了还是成功了),回到主线程更新UI。");
        NSLog(@"count的值为%li",count);
    });
}

/**
 信号量是一个整形值并且具有一个初始计数值，并且支持两个操作：信号通知和等待。当一个信号量被信号通知，其计数会被增加。当一个线程在一个信号量上等待时，线程会被阻塞（如果有必要的话），直至计数器大于零，然后线程会减少这个计数。
 　　在GCD中有三个函数是semaphore的操作，分别是：
 　　dispatch_semaphore_create　　　创建一个semaphore
 　　dispatch_semaphore_signal　　　发送一个信号
 　　dispatch_semaphore_wait　　　　等待信号
 　　简单的介绍一下这三个函数，第一个函数有一个整形的参数，我们可以理解为信号的总量，dispatch_semaphore_signal是发送一个信号，自然会让信号总量加1，dispatch_semaphore_wait等待信号，当信号总量少于0的时候就会一直等待，否则就可以正常的执行，并让信号总量-1。
 */

//- (void)testSemaphore
//{
//    dispatch_group_t group = dispatch_group_create();
//    dispatch_semaphore_t semaphore = dispatch_semaphore_create(10);
//    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    for (NSInteger i = 0; i<100; i++) {
//        
//        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
//        
//        dispatch_group_async(group, queue, ^{
//            NSLog(@"%li",i);
//            sleep(2.0);
//            dispatch_semaphore_signal(semaphore);
//        });
//    }
//    /**
//     创建了一个初使值为10的semaphore，每一次for循环都会创建一个新的线程，线程结束的时候会发送一个信号，线程创建之前会信号等待，所以当同时创建了10个线程之后，for循环就会阻塞，等待有线程结束之后会增加一个信号才继续执行，如此就形成了对并发的控制，如上就是一个并发数为10的一个线程队列
//     */
//
//}
@end

