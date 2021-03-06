//
//  AppDelegate.m
//  commotion-meshbook
//
//  Created by Brad : Scal.io, LLC - http://scal.io
//

#import <Growl/Growl.h>
#import "AppDelegate.h"
#import "MASPreferencesWindowController.h"
#import "ProfilesDoc.h"
#import "ProfilesData.h"
#import "ProfilesDatabase.h"
#import "BLAuthentication.h"
#import "Reachability.h"

// view controllers
#import "StatusViewController.h"
#import "ProfilesViewController.h"
#import "HelpViewController.h"
#import "LogViewController.h"

static NSString *const kMASPreferencesSelectedViewKey = @"MASPreferences Selected Identifier View";

@implementation AppDelegate

//==========================================================
#pragma mark Application Lifecycle
//==========================================================
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    // setup notifications    
    // listen for successful return of json data from localhost
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateMeshMenuItems:)
                                                 name:@"meshDataProcessingComplete"
                                            object:nil];
    // listen for network wifi data poll
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateUserWifiMenuItems:)
                                                 name:@"wifiDataProcessingComplete"
                                               object:nil];

    // setup wifi network
    [self initNetworkInterface];
    
    // setup mesh network
    [self initMeshInterface];

    
    // 'Quit' menu item is enabled always
    [menuQuit setEnabled:YES];
    
    // Enables or disables the receiver’s menu items and sizes the menu to fit its current menu items if necessary.
    [statusMenu update];

}

- (void) awakeFromNib {
    
    // Setup "status menu extra" menulet with icons and mode
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	
	NSImage *meshIcon = [[NSImage alloc] initWithContentsOfFile:
                         [[NSBundle mainBundle] pathForResource:@"menuIcon"
                                                         ofType:@"png"]];
	[statusItem setImage:meshIcon];
    [statusItem setAlternateImage: [NSImage imageNamed:@"menuIconHighlighted"]];
    
    [statusItem setHighlightMode:YES];
    
    // set our delegate here so 'menuWillOpen' is called
    [statusMenu setDelegate:self];
	[statusItem setMenu:statusMenu];
}

//==========================================================
#pragma mark NSMenu Delegate
//==========================================================
// called every time the user opens the menu
- (void)menuWillOpen:(NSMenu *)menu
{
    //NSLog(@"***********************************************************************");

    //NSLog(@"%s-menu: %@", __FUNCTION__, menu);
        
    //NSMenuItem *selectedItem = [menu itemAtIndex:11];
    //NSLog(@"%s: selectedItem: %@", __FUNCTION__, selectedItem.title);
    
    // profiles
    self.profiles = [ProfilesDatabase loadProfilesDocs];
    profileCount = [self.profiles count];
    //NSLog(@"%s: profileCount: %lu", __FUNCTION__, profileCount);
    
    // scanned networks
    //scannedItems = [[NSMutableArray alloc] initWithObjects:@"BMGNet", @"TookieBoo", @"OhYHEANETWORK", nil];
    //scannedItems = [NetworkServiceClass scanAvailableNetworks];
    //NSLog(@"%s: scannedItems: %@", __FUNCTION__, scannedItems);
    
    // reverse the loop
    for ( NSUInteger menuIndex = statusMenu.numberOfItems; menuIndex > 0; --menuIndex ) {
        NSUInteger i = menuIndex - 1;
        
        NSMenuItem *menuItem = [statusMenu itemAtIndex:i];
        //NSLog(@"%s-menuItem: index: %lu - tag: %lu - %@", __FUNCTION__, i, menuItem.tag, menuItem.title);
        
        tag1Index = i;
        //NSLog(@"%s: tag1Index: %lu", __FUNCTION__, tag1Index);
    
        
        // JOIN A MESH NETWORK (profile items from the file system)
        // get index of tag 1
        if (menuItem.tag==1) {
        
            // reverse the loop
            for ( NSUInteger profileIndex = profileCount; profileIndex > 0; --profileIndex ) {
                NSUInteger p = profileIndex - 1;
            
                // get data from our model
                ProfilesDoc *profilesDoc = [self.profiles objectAtIndex:p];
                // add menu item
                NSMenuItem *profileItem = [statusMenu insertItemWithTitle:[NSString stringWithFormat:@"%@", profilesDoc.data.ssid] action:@selector(setChosenNetwork:) keyEquivalent:@"" atIndex:(tag1Index+1)];
                
                // assign each profile a tag within the specified range
                profileItem.tag = p + 100;
                
                //NSLog(@"%s: profileItem tag: %lu", __FUNCTION__, profileItem.tag);
                //NSLog(@"%s-profileItem: index: %lu - tag: %lu - %@", __FUNCTION__, i, profileItem.tag, profileItem.title);
                
                if ([fetchedWifiSSID isEqualToString:profileItem.title]) {
                    [profileItem setState: NSOnState];
                    [menuActiveMesh setTitle:profileItem.title];
                }

                [profileItem setTarget:self];
            }
        }
        
        // CREATE A MESH NETWORK (scanned items from corewlan)
        // get index of tag 1
        if (menuItem.tag==2) {
            
            // reverse the loop
            for ( NSUInteger scannedIndex = [scannedItems count]; scannedIndex > 0; --scannedIndex ) {
                NSUInteger s = scannedIndex - 1;
                
                // get data from our scan
                NSArray *scanItem = [scannedItems objectAtIndex:s];
                
                // add menu item
                NSMenuItem *scannedItem = [statusMenu insertItemWithTitle:[NSString stringWithFormat:@"%@", scanItem] action:@selector(setChosenNetwork:) keyEquivalent:@"" atIndex:(tag1Index+1)];
                
                // assign each profile a tag within the specified range
                scannedItem.tag = s + 200;
                
                //NSLog(@"%s: profileItem tag: %lu", __FUNCTION__, profileItem.tag);
                //NSLog(@"%s-profileItem: index: %lu - tag: %lu - %@", __FUNCTION__, i, scannedItem.tag, scannedItem.title);
                
                if ([fetchedWifiSSID isEqualToString:scannedItem.title]) {
                    [scannedItem setState: NSOnState];
                    [menuActiveMesh setTitle:scannedItem.title];
                }

                [scannedItem setTarget:self];
            }
        }
    }
}

// called when we need to update menu items
- (void)menuNeedsUpdate:(NSMenu *)menu {
    
    //NSLog(@"***********************************************************************");
    
    self.profiles = [ProfilesDatabase loadProfilesDocs];
    profileCount = [self.profiles count];
    //NSLog(@"%s: profileCount: %lu", __FUNCTION__, profileCount);
    //NSLog(@"%s: menu.numberOfItems: %lu", __FUNCTION__, menu.numberOfItems);
    
    // reverse the loop
    for ( NSUInteger loopIndex = statusMenu.numberOfItems; loopIndex > 0; --loopIndex ) {
        NSUInteger i = loopIndex - 1;
        
        NSMenuItem *menuItem = [statusMenu itemAtIndex:i];
        
        //NSLog(@"%s-menuItem: index: %lu - tag: %lu - %@", __FUNCTION__, i, menuItem.tag, menuItem.title);
        
        if ((menuItem.tag >= 100) && (menuItem.tag <= 300)) {
            //NSLog(@"%s-REMOVING menuItem: index: %lu - tag: %lu - %@", __FUNCTION__, i, menuItem.tag, menuItem.title);

            [statusMenu removeItemAtIndex: i];
        }
    }
     
}

// connect to our network
- (void)setChosenNetwork:(NSMenuItem *)selectedNetwork  {
        
    // try starting or connecting to ibss here
    // if tag is in range of 100, we're creating a mesh
    // if tag is in range of 200, we're joining a mesh
    
    wifiOn = [self isWifiOn];
    //NSLog(@"%s-wifiOn: %i", __FUNCTION__, wifiOn);
    
    // network reachability to detect wifi - user must be connected to make selection
    if (wifiOn) {
    
        if ((selectedNetwork.tag >= 100) && (selectedNetwork.tag <= 199)) {
            
            /*** WE ARE CREATING A MESH ***/
            // if creating, we need to find the associated network metadata
            self.profiles = [ProfilesDatabase loadProfilesDocs];
            
            for (ProfilesDoc *profile in self.profiles) {
                //NSLog(@"%s-ssid: %@", __FUNCTION__, profile.data.ssid);
                
                if ([profile.data.ssid isEqualToString:selectedNetwork.title]) {
                    //NSLog(@"%s-profile data: %@", __FUNCTION__, profile.data.channel);
                    [NetworkServiceClass createIBSSNetwork:selectedNetwork.title withChannel:profile.data.channel];
                }
            }
        }
        if ((selectedNetwork.tag >= 200) && (selectedNetwork.tag <= 299)) {

            /*** WE ARE JOINING A MESH ***/
            [NetworkServiceClass joinIBSSNetwork:selectedNetwork.title];
        }
        
        // if success on connection, update active menu items
        [menuSelectedNetwork setTitle:selectedNetwork.title];
        [menuActiveMesh setTitle:selectedNetwork.title];
    }
    else {
        NSRunAlertPanel(@"No Wifi Detected", @"You must have your wifi powered on to connect to a mesh network.", @"OK", nil, nil);
    }
}
                                    
// dont exit the app unless the user explicitly Quits
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return NO;
}


//==========================================================
#pragma mark Network / Mesh Data Setup & Processing
//==========================================================

- (void)initNetworkInterface {
    

    // init wifi networking
    NetworkServiceClass = [[NetworkService alloc] init];
    //fetchedUserWifiData = [NetworkServiceClass scanUserWifiSettings];
    [NetworkServiceClass executeWifiDataPolling];

    //[self updateUserWifiMenuItems];
}

- (void)initMeshInterface {
        
    // Start olsrd process -- this should be started as early as possible
    olsrdProcess = [[OLSRDService alloc] init];
    [olsrdProcess executeOLSRDService];

}

-(void) updateUserWifiMenuItems:(NSNotification *)fetchedWifiData {
    
    NSDictionary *wifiData = [fetchedWifiData userInfo];
    fetchedWifiState = [wifiData valueForKey:@"state"];
    fetchedWifiSSID = [wifiData valueForKey:@"ssid"];
    fetchedWifiBSSID = [wifiData valueForKey:@"bssid"];
    fetchedWifiChannel = [wifiData valueForKey:@"channel"];
    scannedItems = [wifiData valueForKey:@"openNetworks"];
    
    //NSLog(@"%s: scannedItems: %@", __FUNCTION__, scannedItems);
    
    // update menu items with fetched data
	[menuNetworkStatus setTitle:[NSString stringWithFormat:@"Power: %@", fetchedWifiState]];
	[menuNetworkSSID setTitle:[NSString stringWithFormat:@"Network (SSID): %@", fetchedWifiSSID]];
	[menuNetworkBSSID setTitle:[NSString stringWithFormat:@"BSSID: %@", fetchedWifiBSSID]];
    [menuNetworkChannel setTitle:[NSString stringWithFormat:@"Channel: %@", fetchedWifiChannel]];
    
    [self menuNeedsUpdate:nil];
    [self menuWillOpen:nil];
}


-(void) updateMeshMenuItems:(NSNotification *)fetchedMeshData {
  
    //NSLog(@"notification-meshData: %@", [fetchedMeshData userInfo]);
    
    NSDictionary *meshData = [fetchedMeshData userInfo];
    NSString *meshState = [meshData valueForKey:@"state"];
    
    //NSLog(@"%s: meshState: %@", __FUNCTION__, meshState);
    
    // update menu items with fetched info
    [menuMeshStatus setTitle:[NSString stringWithFormat:@"OLSRD: %@", (meshState ? : @"Stopped")]];
    
     [self menuNeedsUpdate:nil];
     [self menuWillOpen:nil];
}


//==========================================================
#pragma mark Menu / Window Controller
//==========================================================

- (NSWindowController *)settingsWindowController
{
    if (_settingsWindowController == nil)
    {
        // here we can create as many tabs as we'd like -- just add another view controller to the stack
        NSViewController *statusViewController = [[StatusViewController alloc] init];
        NSViewController *profilesViewController = [[ProfilesViewController alloc] init];
        NSViewController *helpViewController = [[HelpViewController alloc] init];
        NSViewController *logViewController = [[LogViewController alloc] init];
        NSArray *controllers = [[NSArray alloc] initWithObjects:statusViewController, profilesViewController, helpViewController, logViewController, nil];
        
        _settingsWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:controllers title:@"Settings"];
    }
    return _settingsWindowController;
}

-(IBAction) openSettings: (id)sender {
    
    //NSLog(@"sender: %@", [sender title]);
    
    // Record new selected controller in user defaults
    [[NSUserDefaults standardUserDefaults] setObject:[sender title] forKey:kMASPreferencesSelectedViewKey];
    // Post to update window
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kMenuItemChangeViewControllerTab" object:[sender title]];

    [NSApp activateIgnoringOtherApps:YES];
    
    [self.settingsWindowController showWindow:nil];
}

/** Sets the tab the user was on **/
NSString *const kFocusedAdvancedControlIndex = @"FocusedAdvancedControlIndex";

- (NSInteger)focusedAdvancedControlIndex
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kFocusedAdvancedControlIndex];
}

- (void)setFocusedAdvancedControlIndex:(NSInteger)focusedAdvancedControlIndex
{
    [[NSUserDefaults standardUserDefaults] setInteger:focusedAdvancedControlIndex forKey:kFocusedAdvancedControlIndex];
}

//==========================================================
#pragma mark Reachability
//==========================================================

// check if wifi power is on
- (BOOL)isWifiOn {
    Reachability* wifiReach = [Reachability reachabilityForLocalWiFi];
    
    NetworkStatus netStatus = [wifiReach currentReachabilityStatus];
    //NSLog(@"%i == %i", netStatus, ReachableViaWiFi);
    
    return (netStatus==ReachableViaWiFi);
}


@end
