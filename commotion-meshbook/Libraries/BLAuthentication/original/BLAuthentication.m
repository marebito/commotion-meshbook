//  ====================================================================== 	//
//  BLAuthentication.h														//
//  																		//
//  Last Modified on Tuesday April 24 2001									//
//  Copyright 2001 Ben Lachman												//
//																			//
//	Thanks to Brian R. Hill <http://personalpages.tds.net/~brian_hill/>		//
//  ====================================================================== 	//

#import "BLAuthentication.h"
#import <Security/AuthorizationTags.h>

@implementation BLAuthentication

// returns an instace of itself, creating one if needed
+ sharedInstance {
    static id sharedTask = nil;
    if(sharedTask==nil) {
        sharedTask = [[BLAuthentication alloc] init];
    }
    return sharedTask;
}

// initializes the super class and sets authorizationRef to NULL 
- (id)init {
    self = [super init];
    authorizationRef = NULL;
    return self;
}

// deauthenticates the user and deallocates memory
- (void)dealloc {
    [self deauthenticate];
    
    [super dealloc];
}

//============================================================================
//	- (BOOL)isAuthenticated:(NSArray *)forCommands
//============================================================================
// Find outs if the user has the appropriate authorization rights for the 
// commands listed in (NSArray *)forCommands.
// This should be called each time you need to know whether the user
// is authorized, since the AuthorizationRef can be invalidated elsewhere, or
// may expire after a short period of time.
//
- (BOOL)isAuthenticated:(NSArray *)forCommands {
	AuthorizationRights rights;
	AuthorizationRights *authorizedRights;
	AuthorizationFlags flags;
	
	NSUInteger numItems = [forCommands count];
	AuthorizationItem *items = malloc( sizeof(AuthorizationItem) * numItems );
	char paths[20][128]; // only handles upto 20 commands with paths upto 128 characters in length
	
	OSStatus err = 0;
	BOOL authorized = NO;
	int i = 0;

	if(authorizationRef==NULL) {
		rights.count=0;
		rights.items = NULL;
		
		flags = kAuthorizationFlagDefaults;
		
		err = AuthorizationCreate(&rights, kAuthorizationEmptyEnvironment, flags, &authorizationRef);
	}
    	
    if(!err)
    {
            
        if( numItems < 1 ) {
            return authorized;
        }

        while( i < numItems && i < 20 ) {
             [[forCommands objectAtIndex:i] getCString:paths[i]];
            
            items[i].name = kAuthorizationRightExecute;
            items[i].value = paths[i];
            items[i].valueLength = [[forCommands objectAtIndex:i] cStringLength];
            items[i].flags = 0;
            
            i++;
        }
        
        rights.count = numItems;
        rights.items = items;
        
        flags = kAuthorizationFlagExtendRights;
        
        err = AuthorizationCopyRights(authorizationRef, &rights, kAuthorizationEmptyEnvironment, flags, &authorizedRights);
        
        authorized = (errAuthorizationSuccess==err);

    }
	if(authorized)
		AuthorizationFreeItemSet(authorizedRights);
	
	free(items);
	
    return authorized;
}

//============================================================================
//	- (void)deauthenticate
//============================================================================
// Deauthenticates the user by freeing their authorization.
//
- (void)deauthenticate {
    if(authorizationRef) {
        AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
        authorizationRef = NULL;
        [[NSNotificationCenter defaultCenter]postNotificationName:BLDeauthenticatedNotification object:self];
    }
}

//============================================================================
//	- (BOOL)fetchPassword:(NSArray *)forCommands
//============================================================================
// Adds rights for commands specified in (NSArray *)forCommands.
// Commands should be passed as a NSString comtaining the path to the executable. 
// Returns YES if rights were gained
//
- (BOOL)fetchPassword:(NSArray *)forCommands {
	AuthorizationRights rights;
	AuthorizationRights *authorizedRights;
	AuthorizationFlags flags;
	
	NSUInteger numItems = [forCommands count];
	AuthorizationItem *items = malloc( sizeof(AuthorizationItem) * numItems );
	char paths[20][128];
	
	OSStatus err = 0;
	BOOL authorized = NO;
	int i = 0;
	
	if( numItems < 1 )
		return authorized;
	
	while( i < numItems && i < 20 )
    {
        NSLog(@"%@", [forCommands objectAtIndex:i]);
		[[forCommands objectAtIndex:i] getCString:paths[i]];
		
		items[i].name = kAuthorizationRightExecute;
		items[i].value = paths[i];
		items[i].valueLength = [[forCommands objectAtIndex:i] cStringLength];
		items[i].flags = 0;
		
		i++;
	}
	
	rights.count = numItems;
	rights.items = items;
	
	flags = kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights;
	
	err = AuthorizationCopyRights(authorizationRef, &rights, kAuthorizationEmptyEnvironment, flags, &authorizedRights);
	
	authorized = (errAuthorizationSuccess == err);
	
    if (err != errAuthorizationSuccess) {
        NSRunAlertPanel(@"Cannot run without admin privileges", @"This program cannot start olsrd without administrator access.", @"OK", nil, nil);
        return 1;
    }
    
	if(authorized) {
		AuthorizationFreeItemSet(authorizedRights);
		[[NSNotificationCenter defaultCenter] postNotificationName:BLAuthenticatedNotification object:self];
	}                                                    

	free(items);
	
	return authorized;
}

//============================================================================
//	- (BOOL)authenticate:(NSArray *)forCommands
//============================================================================
// Authenticates the commands in the array (NSArray *)forCommands by calling 
// fetchPassword.
//
- (BOOL)authenticate:(NSArray *)forCommands {
	if( ![self isAuthenticated:forCommands] ) {
        [self fetchPassword:forCommands];
	}
	
	return [self isAuthenticated:forCommands];
}


//============================================================================
//	- (int)getPID:(NSString *)forProcess
//============================================================================
// Retrieves the PID (process ID) for the process specified in 
// (NSString *)forProcess.
// The more specific forProcess is the better your accuracy will be, esp. when 
// multiple versions of the process exist. 
//
- (int)getPID:(NSString *)forProcess {
	FILE* outpipe = NULL;
	NSMutableData* outputData = [NSMutableData data];
	NSMutableData* tempData = [[NSMutableData alloc] initWithLength:512];
	NSString *commandOutput = nil;
	NSString *scannerOutput = nil;
	NSString *popenArgs = [[NSString alloc] initWithFormat:@"/bin/ps -axwwopid,command | grep \"%@\"",forProcess];
	NSScanner *outputScanner = nil;
	NSScanner *intScanner = nil;
	int pid = 0;
	NSUInteger len = 0;
    
    outpipe = popen([popenArgs UTF8String],"r");

	[popenArgs release];

	if(!outpipe) 
    {
        [tempData release];
        NSLog(@"Error opening pipe: %@",forProcess);
        NSBeep();
        return 0;
    }
	
	do {
        [tempData setLength:512];
        len = fread([tempData mutableBytes],1,512,outpipe);
        if( len > 0 ) {
            [tempData setLength:len];
            [outputData appendData:tempData];        
		}
	} while(len==512);
    
	[tempData release];

	pclose(outpipe);
	
	commandOutput = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];    
	
	if( [commandOutput length] > 0 ) {
		outputScanner = [NSScanner scannerWithString:commandOutput];
		
		[commandOutput release];
		
		[outputScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		[outputScanner scanUpToString:forProcess intoString:&scannerOutput];
		
		if( [scannerOutput rangeOfString:@"grep"].length != 0 ) {
			return 0;
		}
		
		intScanner = [NSScanner scannerWithString:scannerOutput];
		
		[intScanner scanInt:&pid];
		
		if( pid ) {
			return pid;
		}
		else {
			return 0;
		}
	}
	else {
		[commandOutput release];

		return 0;
	}
}


//============================================================================
//	-(void)executeCommand:(NSString *)pathToCommand withArgs:(NSArray *)arguments
//============================================================================
// Executes command in (NSString *)pathToCommand with the arguments listed in
// (NSArray *)arguments as root.
// pathToCommand should be a string contain the path to the command 
// (eg., /usr/bin/more), arguments should be an array of strings each containing
// a single argument.
//
-(BOOL)executeCommand:(NSString *)pathToCommand withArgs:(NSArray *)arguments andType:(NSString*)type {
    
    
	char* args[30]; // can only handle 30 arguments to a given command
	OSStatus err = 0;
	unsigned int i = 0;
    FILE *pipe = NULL;
	
	if(![self authenticate:[NSArray arrayWithObject:pathToCommand]])
		return NO;
	
	if( arguments == nil || [arguments count] < 1  ) {
		err = AuthorizationExecuteWithPrivileges(authorizationRef, [pathToCommand fileSystemRepresentation], 0, NULL, NULL);
	}
	else {
		while( i < [arguments count] && i < 19) {
			args[i] = (char*)[[arguments objectAtIndex:i] cString];
			i++;
		}
		args[i] = NULL;
        
        //NSLog(@"[pathToCommand fileSystemRepresentation]: %s", [pathToCommand fileSystemRepresentation]);

		err = AuthorizationExecuteWithPrivileges(authorizationRef, [pathToCommand fileSystemRepresentation],
												0, args, &pipe);
	}


    /**
     * DISPLAYS PROGRAM OUTPUT -- BLOCKS UI IF LEFT ON
     */
    
    /**
     #define MAXLEN 256

    int n;
    char buf[MAXLEN];
    while((n = read(fileno(pipe),buf,sizeof(buf))) != 0){
        NSLog(@"output: %d:",n);
        fflush(stdout);
        write(1,buf,n);
    }
    **/
    /**
    char readBuffer[128];
    if (err == errAuthorizationSuccess) {
        for (;;) {
            NSUInteger bytesRead = read(fileno(pipe), readBuffer, sizeof(readBuffer));
            
            if (bytesRead < 1) break;
            write(fileno(stdout), readBuffer, bytesRead);
        }
    }
     **/
    
    
    //[self processBackgroundThread:err withPipe:pipe];
    
    if(err!=0) {
		//NSBeep();
		NSLog(@"Error %d in AuthorizationExecuteWithPrivileges -- Let's try to re-authenticate...",err);
        
        // we dont need to alert user, we just retry
        /**
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Authentication Failed"];
        [alert setInformativeText:[NSString stringWithFormat:@"There was an error when trying to authenticate.  Please quit the program and try again. \n\n<Error %d in AuthorizationExecuteWithPrivileges>", err]];
        [alert setAlertStyle:NSInformationalAlertStyle];  // or NSCriticalAlertStyle
        [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:nil];
        
         **/
        // check to see if type is olsrd
        //if ([type isEqualToString:@"olsrd"]) {
        // we retry auth here
            [[NSNotificationCenter defaultCenter] postNotificationName:BLshellCommandExecuteFailureNotification object:self];
        //}
        
		return NO;
	}
	else {
        // check to see if type is olsrd
        //if ([type isEqualToString:@"olsrd"]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLshellCommandExecuteSuccessNotification object:self];
        //}
		return YES;
	}
}


//============================================================================
//	- (void)killProcess:(NSString *)commandFromPS
//============================================================================
// Finds and kills the process specified in (NSString *)commandFromPS using ps 
// and kill. (by pid)
// The more specific (ie., closer to matching the actual listing in ps) 
// commandFromPS is the better your accuracy will be, esp. when multiple 
// versions of the process exist.
//
- (BOOL)killProcess:(NSString *)commandFromPS {
	NSString *pid;

	if( ![self isAuthenticated:[NSArray arrayWithObject:commandFromPS]] ) {
		[self authenticate:[NSArray arrayWithObject:commandFromPS]];
	}
	
	pid = [NSString stringWithFormat:@"%d",[self getPID:commandFromPS]];
    
    NSLog(@"killProcess-getPID: %@", pid);
	
	if( [pid intValue] > 0 ) {
		[self executeCommand:@"/bin/kill" withArgs:[NSArray arrayWithObjects: @"-9", commandFromPS, nil] andType:nil];
        NSLog(@"killProcess-killing: %@", pid);
		return YES;
	}
	else {
		//NSBeep();
		NSLog(@"Error killing process %@, invalid PID.",pid);
		return NO;
	}
}	
@end

// BLAuthentication sends these notifications are sent when the user  
// becomes authenticated or deauthenticated.
NSString* BLAuthenticatedNotification = @"BLAuthenticatedNotification";
NSString* BLDeauthenticatedNotification = @"BLDeauthenticatedNotification";
NSString* BLshellCommandExecuteSuccessNotification = @"BLshellCommandExecuteSuccessNotification";
NSString* BLshellCommandExecuteFailureNotification = @"BLshellCommandExecuteFailureNotification";

// Sample notification observer:
/*
    [[NSNotificationCenter defaultCenter] addObserver:self
                                        selector:@selector(userAuthenticated:)
                                        name:BLAuthenticatedNotification
                                        object:[BLAuthentication sharedInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                        selector:@selector(userDeauthenticated:)
                                        name:BLDeauthenticatedNotification
                                        object:[BLAuthentication sharedInstance]];
*/




