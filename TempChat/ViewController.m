//
//  BNRViewController.m
//  TempChat
//
//  Copyright (c) 2014 Big Nerd Ranch, Inc. All rights reserved.
//

#import "ViewController.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

@interface ViewController ()  <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *serverAddressField;
@property (weak, nonatomic) IBOutlet UITableView *messageTable;
@property (weak, nonatomic) IBOutlet UIButton    *connectButton;

@property (strong, nonatomic) NSMutableArray    *messages;
@property (assign, nonatomic) int                socketFD;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.messageTable registerClass:[UITableViewCell class]
              forCellReuseIdentifier:@"UITableViewCell"];
}

- (NSMutableArray *)messages
{
    if (!_messages) {
        _messages = [[NSMutableArray alloc] init];
    }
    
    return _messages;
}

- (IBAction)connect:(UIButton *)sender
{
    sender.enabled = NO;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self connectToServer:self.serverAddressField.text];
        
        // Sleep in order to wait for a message to be prepared
        // by the server.  This will not remain by the time we
        // reach the end of the exercise.
        sleep(1);
        
        // Read welcome message
        [self readFromSocket];
    });
}

#pragma mark - Socket communications

- (void)connectToServer:(NSString *)serverAddress
{
    // Get address information
    struct addrinfo hints, *res;
    
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    
    getaddrinfo([serverAddress UTF8String], "8081", &hints, &res);
    
    // Simulate DNS latency
    sleep(3);
    
    // Create socket and connect
    self.socketFD = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    connect(self.socketFD, res->ai_addr, res->ai_addrlen);
    
    fcntl(self.socketFD, F_SETFL, O_NONBLOCK);
    
    // Create dispatch source for socket
}

- (void)readFromSocket
{
    // Read some data
    char buf[1024];
    ssize_t numBytesRead;
    numBytesRead = recv(self.socketFD, buf, 1023, 0);
    if (numBytesRead < 0) {
        NSLog(@"Error reading from socket, ERRNO = %s", strerror(errno));
        return;
    }
    else if (numBytesRead == 0) {
        NSLog(@"0 bytes available on socket.");
        return;
    }
    
    buf[numBytesRead] = '\0';
    
    NSLog(@"Received %ld bytes: %s", numBytesRead, buf);
    
    NSString *message = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
    [self.messages addObject:message];
    
    NSIndexPath *insertionPath = [NSIndexPath indexPathForRow:([self.messages count] - 1)
                                                    inSection:0];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.messageTable insertRowsAtIndexPaths:@[insertionPath]
                                 withRowAnimation:UITableViewRowAnimationAutomatic];
    });
}

#pragma mark - Table data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"
                                                            forIndexPath:indexPath];
    
    cell.textLabel.text = self.messages[indexPath.row];
    
    return cell;
}

#pragma mark - Text Field Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return YES;
}

@end
