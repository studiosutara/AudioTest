/*
    File:       ViewController.m

    Contains:   Main view controller.

    Written by: DTS

    Copyright:  Copyright (c) 2012 Apple Inc. All Rights Reserved.

    Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
                ("Apple") in consideration of your agreement to the following
                terms, and your use, installation, modification or
                redistribution of this Apple software constitutes acceptance of
                these terms.  If you do not agree with these terms, please do
                not use, install, modify or redistribute this Apple software.

                In consideration of your agreement to abide by the following
                terms, and subject to these terms, Apple grants you a personal,
                non-exclusive license, under Apple's copyrights in this
                original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or
                without modifications, in source and/or binary forms; provided
                that if you redistribute the Apple Software in its entirety and
                without modifications, you must retain this notice and the
                following text and disclaimers in all such redistributions of
                the Apple Software. Neither the name, trademarks, service marks
                or logos of Apple Inc. may be used to endorse or promote
                products derived from the Apple Software without specific prior
                written permission from Apple.  Except as expressly stated in
                this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any
                patent rights that may be infringed by your derivative works or
                by other works in which the Apple Software may be incorporated.

                The Apple Software is provided by Apple on an "AS IS" basis. 
                APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
                WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
                MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
                THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.

                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
                INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
                TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
                DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
                OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
                OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
                OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
                SUCH DAMAGE.

*/

#import "ViewController.h"

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "QServer.h"
#import "QCommandLineConnection.h"

@interface ViewController () <QServerDelegate, QCommandLineConnectionDelegate>

@property (nonatomic, strong, readwrite) IBOutlet UIView *          playerContainerView;
@property (nonatomic, strong, readwrite) IBOutlet UISwitch *        autoStopSwitch;

- (IBAction)startStopAction:(id)sender;

@property (nonatomic, strong, readwrite) AVAudioSession *           session;
@property (nonatomic, strong, readwrite) MPMoviePlayerController *  player;
@property (nonatomic, strong, readwrite) NSTimer *                  autoStopTimer;

@property (nonatomic, strong, readwrite) QServer *                  server;
@property (nonatomic, strong, readwrite) NSTimer *                  networkWatchdogTimer;

@end

@implementation ViewController

- (id)init
{
    self = [super initWithNibName:@"ViewController" bundle:nil];
    if (self != nil) {
        // do nothing
    }
    return self;
}

- (void)viewDidLoad
{
    BOOL        success;
    NSURL *     url;

    [super viewDidLoad];

    self.session = [AVAudioSession sharedInstance];
    assert(self.session != nil);

    success = [self.session setCategory:AVAudioSessionCategoryPlayback error:NULL];
    assert(success);
    
    success = [self.session setActive:YES error:NULL];
    assert(success);
    
    url = [[NSBundle mainBundle] URLForResource:@"ShareAndEnjoy" withExtension:@"wav"];
    assert(url != nil);
    
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.view.frame = self.playerContainerView.bounds;
    [self.playerContainerView addSubview:self.player.view];
    [self.player prepareToPlay];
    self.player.repeatMode = MPMovieRepeatModeOne;
    self.player.shouldAutoplay = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.player != nil) {
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        [self becomeFirstResponder];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.player != nil) {
        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
        [self resignFirstResponder];
    }
    [super viewWillDisappear:animated];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent
{
     if (receivedEvent.type == UIEventTypeRemoteControl) {
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlTogglePlayPause: {
                [self startStopAction: nil];
            } break;
            default: {
            } break;
        }
    }
}

- (IBAction)startStopAction:(id)sender
{
    #pragma unused(sender)
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        [self stop];
    } else {
        [self start];
    }
}

- (void)start
{
    [self.player play];
    if (self.autoStopSwitch.isOn) {
        self.autoStopTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 * 60.0 target:self selector:@selector(autoStopTimerDidFire:) userInfo:nil repeats:NO];
    }
    self.server = [[QServer alloc] initWithDomain:nil type:@"_x-audiotest._tcp" name:nil preferredPort:12345];
    self.server.delegate = self;
    [self.server start];
    self.networkWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval:2 * 60.0 target:self selector:@selector(networkWatchdogTimerDidFire:) userInfo:nil repeats:NO];
}

- (void)autoStopTimerDidFire:(NSTimer *)timer
{
    #pragma unused(timer)
    [self stop];
}

- (void)networkWatchdogTimerDidFire:(NSTimer *)timer
{
    #pragma unused(timer)
    [self stop];
}

- (void)stop
{
    [self.player pause];
    if (self.autoStopTimer != nil) {
        [self.autoStopTimer invalidate];
        self.autoStopTimer = nil;
    }
    if (self.server != nil) {
        self.server.delegate = nil;
        [self.server stop];
        self.server = nil;
    }
    if (self.networkWatchdogTimer != nil) {
        [self.networkWatchdogTimer invalidate];
        self.networkWatchdogTimer = nil;
    }
}

- (id)server:(QServer *)server connectionForInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    #pragma unused(server)
    QCommandLineConnection *    conn;
    
    conn = [[QCommandLineConnection alloc] initWithInputStream:inputStream outputStream:outputStream];
    conn.commandDelegate = self;
    [conn open];
    return conn;
}

- (void)server:(QServer *)server closeConnection:(id)connection
{
    #pragma unused(server)
    QCommandLineConnection *    conn;
    
    conn = (QCommandLineConnection *) connection;
    assert([conn isKindOfClass:[QCommandLineConnection class]]);
    
    conn.delegate = nil;
    [conn close];
}

- (void)commandLineConnection:(QCommandLineConnection *)connection didReceiveCommandLine:(NSString *)commandLine
{
    #pragma unused(commandLine)
    [connection sendCommandLine:[NSString stringWithFormat:@"pong %@", [NSDate date]]];
    [self.networkWatchdogTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:2 * 60.0]];
}

- (void)commandLineConnection:(QCommandLineConnection *)connection willCloseWithError:(NSError *)error
{
    #pragma unused(error)
    [self.server closeOneConnection:connection];
}

@end
