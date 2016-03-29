//
//  AKPcapHandles.h
//  TrafficBotHelper
//
//  Created by Xitong Gao on 18/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//


#import <map>
#import <vector>
#import <algorithm>
#import <string>
#import <pcap.h>


#define DeviceInString(dev) (std::string(dev) + ".in")
#define DeviceOutString(dev) (std::string(dev) + ".out")

typedef void (*loop_callback)(const u_char *user,
							  const struct pcap_pkthdr *header,
							  const u_char *packet);

class AKPcapHandles
{
	typedef std::map<std::string, pcap_t *> HandleMap;
	typedef std::pair<std::string, pcap_t *> HandlePair;
	typedef HandleMap::iterator HandleIterator;
	typedef std::map<std::string, dispatch_group_t> DispatchGroupMap;
	typedef std::pair<std::string, dispatch_group_t> DispatchGroupPair;

private:
	HandleMap _handles;
	DispatchGroupMap _dispatchGroups;
    std::vector<std::string> _loopingHandles;

public:
	explicit AKPcapHandles();
	~AKPcapHandles();

	BOOL open(id dev);
	BOOL open(const char *dev);
    void close(const char *dev);
    std::vector<std::string> devices();

    void setFilter(const char *dev, BOOL inYesOutNo, const char *filter);
	void setFilter(BOOL inYesOutNo, const char *filter);

	void loop(loop_callback callback, NSDictionary **userInfo);
};
