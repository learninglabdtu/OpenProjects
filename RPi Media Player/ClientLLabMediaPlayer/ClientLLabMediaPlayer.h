#ifndef ClientLLabMediaPlayer_h
#define ClientLLabMediaPlayer_h

#include <GenericHttpClient.h>
#include <HTTPSharedClientWrapper.h>
#include <Ethernet.h>
#include <Arduino.h>

#define PORT 9994

// This defines the amount of memory allocated to the playlist items.
// Problems WILL arise if the filename length exceeds MAX_PLAYLIST_ITEM_LENGTH
#define MAX_PLAYLIST_ITEMS 10
#define MAX_PLAYLIST_ITEM_LENGTH 50

class ClientLLabMediaPlayer: public GenericHTTPClient 
{
private:
	String requestAndWait(String request);

	char filename[MAX_PLAYLIST_ITEMS][MAX_PLAYLIST_ITEM_LENGTH];
	char alias[MAX_PLAYLIST_ITEMS][MAX_PLAYLIST_ITEM_LENGTH];

public:
	bool _isPlaying;
	String _filename;
	ClientLLabMediaPlayer();

	bool requestPlayingState();
	void requestPlaylist();

	void stopPlaying();
	void playFile(char* name, bool check);

	void begin(HTTPSharedClientWrapper sharedClient, uint8_t ownerID, IPAddress ip);

	void runLoop();
};

#endif