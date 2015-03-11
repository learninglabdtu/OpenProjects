#include "ClientLLabMediaPlayer.h"

ClientLLabMediaPlayer::ClientLLabMediaPlayer(){}

// Initialize the media player
void ClientLLabMediaPlayer::begin(HTTPSharedClientWrapper sharedClient, uint8_t ownerID, IPAddress ip) {
	_ip = ip;
	GenericHTTPClient::begin(sharedClient, ownerID);
}

// Request the player state. Response is sent to the callback function
bool ClientLLabMediaPlayer::requestPlayingState() {
	return GenericHTTPClient::sendRaw("IS_PLAYING", _ip, PORT);
}

// Request the current playlist from the media player
// Response is sent to the callback function if set.
void ClientLLabMediaPlayer::requestPlaylist() {
	GenericHTTPClient::sendRaw("LIST", _ip, PORT);
}

// Plays the file with filename 'name', if it exists in the playlist
// Setting check to false overrides this check
// Note that both filename and alias can be used to start playback
void ClientLLabMediaPlayer::playFile(char* name, bool check) {
	if(strlen(name) > 0) {
		bool didMatch = false;
		for(int i = 0; i < MAX_PLAYLIST_ITEMS; i++) {
			// Check if the string in name matches any filename or alias
			if(strcmp(name, filename[i]) == 0 || strcmp(name, alias[i]) == 0 || !check) {
				char cmd[11+MAX_PLAYLIST_ITEM_LENGTH] = "PLAY:file=";
				strcat(cmd, name);
				GenericHTTPClient::sendRaw(cmd , _ip, PORT);
				didMatch = true;
				break;
			}
		}
		if(!didMatch && _serialOutput) {
			Serial.print("The name '");
			Serial.print(name);
			Serial.println("' did not match any stored file name or alias.");
		}
	}
}

// Stops the currently playing file or stream
void ClientLLabMediaPlayer::stopPlaying() {
	GenericHTTPClient::sendRaw("STOP", _ip, PORT);
}

// MediaPlayer runLoop
void ClientLLabMediaPlayer::runLoop() {
	String response = GenericHTTPClient::receiveData();
	// The response is parsed, and action is taken according to the last command executed
	if (response) {
		// Remove trailing newline from response
		if(response[response.length()-1] == '\n') {
			response = response.substring(0,response.length() - 1);
		}
		// Boolean state. Only useful if the command in question can only return TRUE/FALSE
		bool state = response.startsWith("TRUE");

		if(_lastRequest == "IS_PLAYING") {
			_isPlaying = !response.startsWith("FALSE");
			if(_isPlaying) {
				// Takes the filename from the response CURRENTLY_PLAYING:<filename>
				_filename = response.substring(18);
			} else {
				_filename = false;
			}
		} else if(_lastRequest == "LIST") {
			// This receives the playlist from the media player
			memset(filename, 0x00, sizeof(filename));
			memset(alias, 0x00, sizeof(alias));

			char res[256];
			response.toCharArray(res, 256);

			// Parsing of playlist items list
			int start = 0;
			int i = 0;
			int k;
			for(int j = 0; j < strlen(res); j++) {
				if(res[j] == '\n') {
					for(k=j; k > 0; k--) {
						if(res[k] == '"') {
							k=j;
							break;
						}
						if(res[k]==' ') {
							break;
						}
					}
					strncpy(filename[i], res+start, k-start);
					filename[i][k-start] = 0x00;
					if(k<j) {
						strncpy(alias[i], res + k + 1, j-k-1);
						alias[i][k-j-1] = 0x00;
					}
					if(++i >= MAX_PLAYLIST_ITEMS) {
						break;
					}

					start = j+1;
				}
			}
 		}

 		// Communicate the received response to a callback function
		if(_responseCallback) {
			_responseCallback(_lastRequest, response, true);
		}

		if(_serialOutput > 1) {
			Serial.print("Response to '" + _lastRequest + "' : ");
			Serial.println(response);
		} 
	}
}