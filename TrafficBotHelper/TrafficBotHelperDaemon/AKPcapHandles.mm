//
//  AKPcapHandles.mm
//  TrafficBotHelper
//
//  Created by Xitong Gao on 18/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <pthread.h>
#import "AKPcapHandles.h"
#import "AKNetworkInterface.h"

AKPcapHandles::AKPcapHandles()
    : _handles()
{
}

AKPcapHandles::~AKPcapHandles()
{
    // TODO assert all handles are closed
}

BOOL AKPcapHandles::open(id dev)
{
	if ([dev isKindOfClass:[AKNetworkInterface class]])
	{
		dev = [(AKNetworkInterface *)dev name];
	}
	ZAssert([dev isKindOfClass:[NSString class]], @"dev must be an NSString or AKNetworkInterface instance, %@ found", NSStringFromClass([dev class]));
	const char *devName = [dev cStringUsingEncoding:NSASCIIStringEncoding];
	return this->open(devName);
}

BOOL AKPcapHandles::open(const char *dev)
{
	char errbuf[PCAP_ERRBUF_SIZE];
    DLog(@"opening: %s.in", dev);
	pcap_t *inHandle = pcap_open_live(dev, 1, 0, 1000, errbuf);
	ZAssert(inHandle, @"pcap_open_live: %s", errbuf);
    DLog(@"opening: %s.out", dev);
    pcap_t *outHandle = pcap_open_live(dev, 1, 0, 1000, errbuf);
	ZAssert(outHandle, @"pcap_open_live: %s", errbuf);

    if (!inHandle || !outHandle) return NO;

	_handles.insert(HandlePair(DeviceInString(dev), inHandle));
    _handles.insert(HandlePair(DeviceOutString(dev), outHandle));

    return YES;
}

void AKPcapHandles::close(const char *dev)
{
    DLog(@"FIXME shouldn't've close interfaces, it would cause readings to multiply.");

    void (^closeBlock)(const char *dev) = ^ (const char *dev)
    {
        pcap_t *handle = _handles[dev];
        if (!handle) return;

        std::vector<std::string>::iterator itr = std::find(_loopingHandles.begin(), _loopingHandles.end(), dev);
        if (itr != _loopingHandles.end())
        {
            DLog(@"breaking: %s", dev);
            pcap_breakloop(handle);
            dispatch_group_t group = _dispatchGroups[dev];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            dispatch_release(group);
            _dispatchGroups.erase(dev);
            _loopingHandles.erase(itr);
        }
        DLog(@"closing: %s", dev);
        pcap_close(handle);
        _handles.erase(dev);
    };

    closeBlock(DeviceInString(dev).c_str());
    closeBlock(DeviceOutString(dev).c_str());
}

std::vector<std::string> AKPcapHandles::devices()
{
    std::vector<std::string> devices;
    for (HandleIterator itr = _handles.begin();
		 itr != _handles.end();
		 ++itr)
	{
		devices.push_back(itr->first);
	}
    return devices;
}

void AKPcapHandles::setFilter(const char *dev, BOOL inYesOutNo, const char *filter)
{
    struct bpf_program fp;
    pcap_t *handle = _handles[inYesOutNo ? DeviceInString(dev) : DeviceOutString(dev)];
    if (pcap_compile(handle, &fp, filter, 0, 0) == -1)
    {
        DLog(@"couldn't parse filter %s: %s\n", filter, pcap_geterr(handle));
    }
    if (pcap_setfilter(handle, &fp) == -1)
    {
        DLog(@"couldn't install filter %s: %s\n", filter, pcap_geterr(handle));
    }
    pcap_freecode(&fp);
}

void AKPcapHandles::setFilter(BOOL inYesOutNo, const char *filter)
{
    ZAssert(0, @"Do not use: outdated implementation");
	for (HandleIterator itr = _handles.begin();
		 itr != _handles.end();
		 ++itr)
	{
        this->setFilter(itr->first.c_str(), inYesOutNo, filter);
	}
}

void AKPcapHandles::loop(loop_callback callback, NSDictionary **userInfo)
{
    for (HandleIterator itr = _handles.begin();
         itr != _handles.end();
         ++itr)
    {
        if (std::find(_loopingHandles.begin(), _loopingHandles.end(), itr->first)
            != _loopingHandles.end())
            continue;

        _loopingHandles.push_back(itr->first);

        NSDictionary *info = [[NSDictionary alloc] initWithDictionary:*userInfo];

        NSString *dispatchName = [@"com.akkloca.TrafficBotHelper.AKPcapHandles."
                                  stringByAppendingString:
                                  [NSString stringWithCString:itr->first.c_str()
                                                     encoding:NSASCIIStringEncoding]];
		dispatch_group_t group = dispatch_group_create();
		_dispatchGroups[itr->first] = group;
        dispatch_queue_t queue = dispatch_queue_create(
                [dispatchName cStringUsingEncoding:NSASCIIStringEncoding], NULL);
        dispatch_group_async
            (group, queue,
               ^ {
                   const char *dev = itr->first.c_str();
                   NSString *devName = [NSString stringWithCString:dev encoding:NSASCIIStringEncoding];
                   NSMutableDictionary *infoDict = [info mutableCopy];
                   [infoDict setValue:[devName stringByDeletingPathExtension] forKey:@"dev"];
                   [infoDict setValue:[devName pathExtension] forKey:@"type"];

                   DLog(@"looping: %s", dev);
                   pcap_loop(itr->second, -1, (pcap_handler)callback, (u_char *)infoDict);

                   [infoDict release];
               });
		dispatch_release(queue);

		[info release];
    }
}
