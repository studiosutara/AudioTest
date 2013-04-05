/*
    File:       main.m

    Contains:   Command line tool main.

    Written by: DTS

    Copyright:  Copyright (c) 2013 Apple Inc. All Rights Reserved.

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

#import <Foundation/Foundation.h>

#include "QCommandLineConnection.h"

@interface NSStream (QNetworkAdditions)
 
+ (void)qNetworkAdditions_getStreamsToHostNamed:(NSString *)hostName
    port:(NSInteger)port
    inputStream:(out NSInputStream **)inputStreamPtr
    outputStream:(out NSOutputStream **)outputStreamPtr;
 
@end
 
@implementation NSStream (QNetworkAdditions)
 
+ (void)qNetworkAdditions_getStreamsToHostNamed:(NSString *)hostName
    port:(NSInteger)port
    inputStream:(out NSInputStream **)inputStreamPtr
    outputStream:(out NSOutputStream **)outputStreamPtr
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
 
    assert(hostName != nil);
    assert( (port > 0) && (port < 65536) );
    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );
 
    readStream = NULL;
    writeStream = NULL;
 
    CFStreamCreatePairWithSocketToHost(
        NULL,
        (__bridge CFStringRef) hostName,
        (UInt32) port,
        ((inputStreamPtr  != NULL) ? &readStream : NULL),
        ((outputStreamPtr != NULL) ? &writeStream : NULL)
    );
 
    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}
 
@end

@interface Main : NSObject

- (id)initWithHostName:(NSString *)hostName port:(NSInteger)port;

@property (nonatomic, copy,   readonly ) NSString *     hostName;
@property (nonatomic, assign, readonly ) NSInteger      port;

- (void)start;

@end

@interface Main () <QCommandLineConnectionDelegate>

@property (nonatomic, strong, readwrite) QCommandLineConnection *   connection;
@property (nonatomic, strong, readwrite) NSTimer *                  pingTimer;

@end

@implementation Main

- (id)initWithHostName:(NSString *)hostName port:(NSInteger)port
{
    self = [super init];
    if (self != nil) {
        self->_hostName = hostName;
        self->_port = port;
    }
    return self;
}

- (void)start
{
    NSInputStream *    inStream;
    NSOutputStream *   outStream;
    
    [NSStream qNetworkAdditions_getStreamsToHostNamed:self.hostName port:self.port inputStream:&inStream outputStream:&outStream];
    self.connection = [[QCommandLineConnection alloc] initWithInputStream:inStream outputStream:outStream];
    self.connection.commandDelegate = self;
    [self.connection open];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:25.0 target:self selector:@selector(pingTimerDidFire:) userInfo:nil repeats:YES];
}

- (void)pingTimerDidFire:(NSTimer *)timer
{
    #pragma unused(timer)
    [self.connection sendCommandLine:[NSString stringWithFormat:@"ping %@", [NSDate date]]];
}

- (void)commandLineConnection:(QCommandLineConnection *)connection didReceiveCommandLine:(NSString *)commandLine
{
    #pragma unused(connection)
    fprintf(stderr, "%s", [commandLine UTF8String]);
}

- (void)commandLineConnection:(QCommandLineConnection *)connection willCloseWithError:(NSError *)error
{
    #pragma unused(connection)
    if (error == nil) {
        fprintf(stderr, "EOF\n");
        exit(EXIT_SUCCESS);
    } else {
        fprintf(stderr, "error %s / %d\n", [[error domain] UTF8String], (int) [error code]);
        exit(EXIT_FAILURE);
    }
}

@end

int main(int argc, char **argv)
{
    #pragma unused(argc)
    #pragma unused(argv)
    int                 retVal;

    @autoreleasepool {
        retVal = EXIT_SUCCESS;
        if (argc != 3) {
            retVal = EXIT_FAILURE;
        }
        
        if (retVal != EXIT_SUCCESS) {
            fprintf(stderr, "usage: %s host port\n", getprogname());
        } else {
            Main * m;
            
            m = [[Main alloc] initWithHostName:@(argv[1]) port:atoi(argv[2])];
            [m start];
            [[NSRunLoop currentRunLoop] run];
        }
    }

    return retVal;
}
