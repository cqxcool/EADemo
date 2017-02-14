/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    View controller to allow transferring data to and from an accessory form the UI.
 */


#import "EADSessionTransferViewController.h"
#import "EADSessionController.h"

@interface EADSessionTransferViewController ()

@property(nonatomic) uint32_t totalBytesRead;
@property(nonatomic) uint32_t totalBytesWrite;

@property(nonatomic, strong) IBOutlet EAAccessory *accessory;
@property(nonatomic, strong) IBOutlet UILabel *receivedBytesCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *receviedSpeedLabel;
@property (weak, nonatomic) IBOutlet UILabel *avgSpeedLabel;
@property(nonatomic, strong) IBOutlet UITextField *stringToSendText;
@property(nonatomic, strong) IBOutlet UITextField *hexToSendText;

@property(nonatomic, assign) NSTimeInterval sendTimeStamp;
@property(nonatomic, assign) NSTimeInterval sendOnecTimeStamp;

@property(nonatomic, assign) NSInteger       sendSize;
@property(nonatomic, assign) CGFloat        lastSpeed;
@property(nonatomic, assign) NSTimeInterval lastReceiveTimeStamp;
@property(nonatomic, assign) NSTimeInterval startReceiveTimeStamp;

@property (weak, nonatomic) IBOutlet UIStepper *stepper10KB;
@property (weak, nonatomic) IBOutlet UIStepper *stepper1MB;
@property (weak, nonatomic) IBOutlet UIStepper *stepper10MB;
@property (weak, nonatomic) IBOutlet UIButton *send10KButton;
@property (weak, nonatomic) IBOutlet UIButton *send1MButton;
@property (weak, nonatomic) IBOutlet UIButton *send10MBButton;
@property (weak, nonatomic) IBOutlet UILabel *sendBytesLabel;
@property (weak, nonatomic) IBOutlet UILabel *sendSpeedLabel;

@end

@implementation EADSessionTransferViewController

// send test string to the accessory
- (IBAction)sendStringButtonPressed:(id)sender;
{
    if ([_stringToSendText isFirstResponder]) {
        [_stringToSendText resignFirstResponder];
    }

    const char *buf = [[_stringToSendText text] UTF8String];
    if (buf)
    {
        uint32_t len = (uint32_t)strlen(buf) + 1;
        [[EADSessionController sharedController] writeData:[NSData dataWithBytes:buf length:len]];
    }
}

// Interpret a UITextField's string at a sequence of hex bytes and send those bytes to the accessory
- (IBAction)sendHexButtonPressed:(id)sender;
{
    if ([_hexToSendText isFirstResponder]) {
        [_hexToSendText resignFirstResponder];
    }

    const char *buf = [[_hexToSendText text] UTF8String];
    NSMutableData *data = [NSMutableData data];
    if (buf)
    {
        uint32_t len = (uint32_t)strlen(buf);

        char singleNumberString[3] = {'\0', '\0', '\0'};
        uint32_t singleNumber = 0;
        for(uint32_t i = 0 ; i < len; i+=2)
        {
            if ( ((i+1) < len) && isxdigit(buf[i]) && (isxdigit(buf[i+1])) )
            {
                singleNumberString[0] = buf[i];
                singleNumberString[1] = buf[i + 1];
                sscanf(singleNumberString, "%x", &singleNumber);
                uint8_t tmp = (uint8_t)(singleNumber & 0x000000FF);
                [data appendBytes:(void *)(&tmp) length:1];
            }
            else
            {
                break;
            }
        }

        [[EADSessionController sharedController] writeData:data];
    }
}

// send 10K of data to the accessory.
- (IBAction)send10KButtonPressed:(id)sender
{
#define STRESS_TEST_BYTE_COUNT (10*1024)
    int mutiple = self.stepper10KB.value;
    self.sendSize = STRESS_TEST_BYTE_COUNT * mutiple;
    self.sendTimeStamp = [[NSDate date] timeIntervalSince1970];

    for (int i = 0 ; i < mutiple; i++) {
        NSLog(@"send10KButtonPressed");
        uint8_t buf[STRESS_TEST_BYTE_COUNT];
        for(int i = 0; i < STRESS_TEST_BYTE_COUNT; i++) {
            buf[i] = (i & 0xFF);  // fill buf with incrementing bytes;
        }
        [[EADSessionController sharedController] writeData:[NSData dataWithBytes:buf length:STRESS_TEST_BYTE_COUNT]];
    }

}
- (IBAction)send10MBButtonPressed:(id)sender
{
    int length = 1024*1024*10;
    int mutiple = self.stepper10MB.value;
    self.sendSize = length * mutiple;
    self.sendTimeStamp = [[NSDate date] timeIntervalSince1970];
    for (int i = 0 ; i<mutiple; i++) {
        NSLog(@"send10MBButtonPressed");
        NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
        [[EADSessionController sharedController] writeData:data];
    }
}
- (IBAction)send1MBButtonPressed:(id)sender
{
    int mutiple = self.stepper1MB.value;
    int length = 1024*1024*mutiple;
    self.sendSize = length;
    NSLog(@"send%dMB",mutiple);
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    [[EADSessionController sharedController] writeData:data];
}
- (IBAction)step10KBValueChange:(id)sender
{
    NSLog(@"value change = %.1f",self.stepper10KB.value);
    [self.send10KButton setTitle:[NSString stringWithFormat:@"Send %d0KB",(int)self.stepper10KB.value] forState:UIControlStateNormal];

}
- (IBAction)setp1MBValueChange:(id)sender
{
    NSLog(@"value change = %.1f",self.stepper1MB.value);
    [self.send1MButton setTitle:[NSString stringWithFormat:@"Send %dMB",(int)self.stepper1MB.value] forState:UIControlStateNormal];
}
- (IBAction)step10MBValueChange:(id)sender
{
    NSLog(@"value change = %.1f",self.stepper10MB.value);
    [self.send10MBButton setTitle:[NSString stringWithFormat:@"Send %d0MB",(int)self.stepper10MB.value] forState:UIControlStateNormal];

}

- (IBAction)send100MBButtonPressed:(id)sender
{
    NSLog(@"send100MBButtonPressed");
    NSMutableData *data = [[NSMutableData alloc] initWithLength:1024*1024*100];
    self.sendTimeStamp = [[NSDate date] timeIntervalSince1970];
    self.sendSize = data.length;
    [[EADSessionController sharedController] writeData:data];

}
- (IBAction)resetButtonTouch:(id)sender
{
    self.lastSpeed = 0;
    self.lastReceiveTimeStamp = 0;
    self.startReceiveTimeStamp = 0;
    _totalBytesRead = 0;
    self.receviedSpeedLabel.text = @"0KB/s";
    self.avgSpeedLabel.text = @"0KB/s";
    self.receivedBytesCountLabel.text = @"0Bytes";
}
- (IBAction)sendReset:(id)sender {
    self.sendSpeedLabel.text = @"0KB/s";
    self.sendBytesLabel.text = @"0Bytes";
    _totalBytesWrite = 0;
    self.sendOnecTimeStamp = 0;
}


#pragma mark UIViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // watch for the accessory being disconnected
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
    // watch for received data from the accessory
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sessionDataReceived:) name:EADSessionDataReceivedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sessionDataWrited:) name:EADSessionDataWritedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sessionDataWritedOnce:) name:EADSessionDataWritedOnceNotification object:nil];



    EADSessionController *sessionController = [EADSessionController sharedController];

    _accessory = [sessionController accessory];
    [self setTitle:[sessionController protocolString]];
    [sessionController openSession];
    _totalBytesRead = 0;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // remove the observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EADSessionDataReceivedNotification object:nil];

    EADSessionController *sessionController = [EADSessionController sharedController];

    [sessionController closeSession];
//    _accessory = nil;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark Internal

- (void)_accessoryDidDisconnect:(NSNotification *)notification
{
    if ([[self navigationController] topViewController] == self)
    {
        EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
        if ([disconnectedAccessory connectionID] == [_accessory connectionID])
        {
            [[self navigationController] popViewControllerAnimated:YES];

        }
    }
}

// Data was received from the accessory, real apps should do something with this data but currently:
//    1. bytes counter is incremented
//    2. bytes are read from the session controller and thrown away
- (void)_sessionDataReceived:(NSNotification *)notification
{
    EADSessionController *sessionController = (EADSessionController *)[notification object];
    NSInteger newLength = 0;
    uint32_t bytesAvailable = 0;

    while ((bytesAvailable = (uint32_t)[sessionController readBytesAvailable]) > 0) {
        NSData *data = [sessionController readData:bytesAvailable];
        if (data) {
            newLength += bytesAvailable;
            _totalBytesRead = _totalBytesRead + bytesAvailable;
        }
    }

   
    NSTimeInterval currentTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;
  
    if (self.lastReceiveTimeStamp && newLength) {
        NSTimeInterval timeRange = currentTimeStamp - self.lastReceiveTimeStamp;
        CGFloat speed = newLength*1000/1024.0/timeRange;
        NSString *stringSpeed = [NSString stringWithFormat:@"%.1fKB/s",speed];
        self.receviedSpeedLabel.text = stringSpeed;
    }
    if (self.startReceiveTimeStamp && self.lastReceiveTimeStamp) {
        NSTimeInterval timeRange = currentTimeStamp - self.startReceiveTimeStamp;
        CGFloat speed = _totalBytesRead*1000/1024.0/timeRange;
        NSString *avgSpeedString = [NSString stringWithFormat:@"%.1fKB/s",speed];
        self.avgSpeedLabel.text = avgSpeedString;
    }
    if (self.startReceiveTimeStamp <= 0) {
        self.startReceiveTimeStamp = currentTimeStamp;
    }
    self.lastReceiveTimeStamp = currentTimeStamp;
    [_receivedBytesCountLabel setText:[NSString stringWithFormat:@"%u Bytes", (unsigned int)_totalBytesRead]];
}

- (void)_sessionDataWrited:(NSNotification *)notification
{
    NSInteger time = [[NSDate date] timeIntervalSince1970] - self.sendTimeStamp;
    CGFloat speed = self.sendSize/1024.0/time;
    NSString *message = [NSString stringWithFormat:@"sendtime:%ldseconds\nspeed:%.1fKB/s",(long)time,speed];
   UIAlertView *alert =  [[UIAlertView alloc] initWithTitle:@"Send Complete" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)_sessionDataWritedOnce:(NSNotification *)notification
{
    NSInteger writeBytes = [notification.object integerValue];
    if (self.sendOnecTimeStamp) {
        NSInteger time = [[NSDate date] timeIntervalSince1970] - self.sendOnecTimeStamp;
        CGFloat speed = writeBytes/1024.0/time;
        self.sendSpeedLabel.text = [NSString stringWithFormat:@"%fKB/s",speed];
        _totalBytesRead += writeBytes;
        self.sendBytesLabel.text = [NSString stringWithFormat:@"%dBytes",_totalBytesWrite];
    }
    self.sendOnecTimeStamp = [[NSDate date] timeIntervalSince1970];
    
}


@end
