//
//  NetworkService.m
//  commotion-meshbook
//
//  Created by Brad : Scal.io, LLC - http://scal.io
//

#import <Growl/Growl.h>
#import <CoreWLAN/CoreWLAN.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import "BLAuthentication.h"

#import "NetworkService.h"

@implementation NetworkService

@synthesize currentInterface = _currentInterface;
@synthesize scanResults = scanResults;

//==========================================================
#pragma mark Initialization & Run Loop
//==========================================================

-(id) init {
    //NSLog(@"NetworkService.h: init");
    
	if (![super init]) return nil;
    
    /**
    // setup notifications
    // listen for successful return of olsrd shell process starting
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(shellCommandExecuteSuccess:)
                                                 name:BLshellCommandExecuteSuccessNotification
                                               object:[BLAuthentication sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(shellCommandExecuteFailure:)
                                                 name:BLshellCommandExecuteFailureNotification
                                               object:[BLAuthentication sharedInstance]];
    **/
    
    
    // get interface array (common == 'en1')
    NSArray *supportedInterfaces = [CWInterface supportedInterfaces];
    //NSLog(@"[supportedInterfaces objectAtIndex:0: %@", [supportedInterfaces objectAtIndex:0]);
    
    // init network interface with 'en1'
    currentInterface = [CWInterface interfaceWithName:[supportedInterfaces objectAtIndex:0]];
    //NSLog(@"currentInterface: %@", currentInterface);
    
    return self;
}

//==========================================================
#pragma mark CoreWLAN Fetch & Processing
//==========================================================

- (NSDictionary *) scanUserWifiSettings {

    // get data from CoreWLAN wireless interface
    powerState = [currentInterface power];
    NSString *power;
    if (powerState==NO) { power=@"Off"; } else { power=@"On";}
    
    ssid = ([currentInterface ssid] ? : @"");
    bssid = ([currentInterface bssid] ? : @"");
    channel = ([currentInterface channel] ? : 0);
    
    
    //NSLog(@"powerState: %i", powerState);
    //NSLog(@"Network (SSID): %@", ssid);
    //NSLog(@"BSSID: %@", bssid);
    //NSLog(@"CHANNEL: %@", channel);
    
	NSDictionary *userWifiData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         power, @"state",
                                         ssid, @"ssid",
                                         bssid, @"bssid",
                                         (channel ? : @""), @"channel",
                                         nil];
    return userWifiData;
}

- (NSMutableArray *)scanAvailableNetworks:(NSString *)networkName {
    NSError *err = nil;
    CWNetwork *currentNetwork = nil;
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:nil];
        
	scanResults = [NSMutableArray arrayWithArray:[currentInterface scanForNetworksWithParameters:params error:&err]];
    //NSLog(@"scanResults: %@",scanResults);
    
  	if( err ) {
		NSLog(@"error: %@",err);
        //[[NSAlert alertWithError:err] runModal];
    }
	else {
		[scanResults sortUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"ssid" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    }
    
    //scannedNetworkData = [NSDictionary dictionary];
    //scannedNetworks = [NSMutableDictionary dictionary];
    scannedNetworks = [[NSMutableArray alloc] init];
        
    for (currentNetwork in scanResults) {
        
        //NSLog(@"SSID %@ - BSSID %@ - CHANNEL %@", [currentNetwork ssid], [currentNetwork bssid], [currentNetwork channel]);
        //NSLog(@"SSID %@ - IBSS %i", [currentNetwork ssid], [currentNetwork ibss]);
        
        // we only want to grab open adhoc (ibss) networks
        if ([currentNetwork ibss]==1) {
            
            // we look at passed method var to see if we're trying to return a single object
            if ((networkName != nil) && ([networkName isEqualToString:[currentNetwork ssid]]) ) {
                
                [scannedNetworks addObject:currentNetwork];
                return scannedNetworks;
            }
            
            [scannedNetworks addObject:[currentNetwork ssid]];
        
            /**  IF WE WANT TO STORE MORE INFO ABOUT THE IBSS (BSSID AND CHANNEL)
            scannedNetworkData = [NSDictionary dictionaryWithObjectsAndKeys: 
                                           [currentNetwork bssid], @"bssid",
                                           [currentNetwork channel], @"channel",
                                           nil];
            
            [scannedNetworks setObject: scannedNetworkData forKey:[currentNetwork ssid]];
             **/
        }
    }
    
    return scannedNetworks;
} 


//==========================================================
#pragma mark Network Management
//==========================================================
- (BOOL) createIBSSNetwork:(NSString *)networkName {
    
    [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                description:[NSString stringWithFormat:@"Attempting to create: %@", networkName]
                           notificationName:@"meshbookGrowlNotification"
                                   iconData:nil
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
    
    
	//NSString *networkName = [ibssNetworkNameField stringValue];
	NSNumber *passedChannel = [NSNumber numberWithInt:2];
    // we set no security here?
    NSString *passphrase = @"";
    
	NSMutableDictionary *ibssParamsForCreate = [NSMutableDictionary dictionaryWithCapacity:0];
	if( networkName && [networkName length] )
		[ibssParamsForCreate setValue:networkName forKey:kCWIBSSKeySSID];
	if( passedChannel && [passedChannel intValue] > 0 )
		[ibssParamsForCreate setValue:passedChannel forKey:kCWIBSSKeyChannel];
    if( passphrase && [passphrase length] )
		[ibssParamsForCreate setValue:passphrase forKey:kCWIBSSKeyPassphrase];
    
    //NSLog(@"networkName: %@", networkName);
    //NSLog(@"channel: %@", passedChannel);
    //NSLog(@"ibssParams: %@", ibssParamsForCreate);
    
    
	NSError *error = nil;
    BOOL created = [currentInterface enableIBSSWithParameters:[NSDictionary dictionaryWithDictionary:ibssParamsForCreate] error:&error];

	if( !created )
	{
		[[NSAlert alertWithError:error] runModal];
        
        return NO;
	}
    else {
    
        // growl notification
        [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                    description:[NSString stringWithFormat:@"Successfully created: %@", networkName]
                               notificationName:@"meshbookGrowlNotification"
                                       iconData:nil
                                       priority:0
                                       isSticky:NO
                                   clickContext:nil];
        return YES;
    }
}


- (BOOL) joinIBSSNetwork:(NSString *)networkName {
    
    [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                description:[NSString stringWithFormat:@"Attempting to join: %@", networkName]
                           notificationName:@"meshbookGrowlNotification"
                                   iconData:nil
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
    
    // we need to get a CW object for passed network name
    NSArray *scannedItems = [self scanAvailableNetworks:networkName];
    //NSLog(@"scannedItems: %@", scannedItems);
    
    CWNetwork *selectedNetwork = [scannedItems objectAtIndex:0];

    NSMutableDictionary *ibssParamsForJoin = [NSMutableDictionary dictionaryWithCapacity:0];
	if( networkName ) {
		[ibssParamsForJoin setValue:networkName forKey:kCWIBSSKeySSID];
    }
    //[ibssParamsForJoin setValue:passphrase forKey:kCWAssocKeyPassphrase];
    
    //NSLog(@"networkName: %@", networkName);

	NSError *error = nil;
    BOOL joined = [currentInterface associateToNetwork:selectedNetwork parameters:[NSDictionary dictionaryWithDictionary:ibssParamsForJoin] error:&error];
    
	if( !joined )
	{
		[[NSAlert alertWithError:error] runModal];
        
        return NO;
	}
    else {
        
        // growl notification
        [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                    description:[NSString stringWithFormat:@"Successfully joined: %@", networkName]
                               notificationName:@"meshbookGrowlNotification"
                                       iconData:nil
                                       priority:0
                                       isSticky:NO
                                   clickContext:nil];
        return YES;
    }
}


@end
