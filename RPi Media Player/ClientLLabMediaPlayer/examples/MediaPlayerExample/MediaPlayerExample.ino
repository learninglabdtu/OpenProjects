#include <SPI.h>
#include <Ethernet.h>
#include <utility/w5100.h>
#include <MemoryFree.h>


// No-cost stream operator as described at 
// http://arduiniana.org/libraries/streaming/
template<class T>
inline Print &operator <<(Print &obj, T arg)
{  
  obj.print(arg); 
  return obj; 
}

#include <HTTPSharedClientWrapper.h>
#include <SkaarhojBufferTools.h>
#include <SkaarhojASCIIClient.h>
#include <GenericHTTPClient.h>
#include <ClientLLabMediaPlayer.h>

HTTPSharedClientWrapper sharedClient;
ClientLLabMediaPlayer MediaPlayer;

#include <SkaarhojSerialServer.h>
SkaarhojSerialServer SerialServer(Serial);

IPAddress serverip(10,0,0,126);

// MAC address and IP address for this *particular* Arduino / Ethernet Shield!
// The MAC address is printed on a label on the shield or on the back of your device
// The IP address should be an available address you choose on your subnet where the switcher is also present
byte mac[] = { 0x90, 0xA2, 0xDA, 0x0D, 0x6B, 0xB9 };      // <= SETUP!  MAC address of the Arduino
IPAddress ip(10, 0, 0, 249);                 // <= SETUP!  IP address of the Arduino

void handleSerialIncoming()  { 
  char* serialBuffer = SerialServer.getRemainingBuffer();
  if(SerialServer.isBufferEqualTo_P(PSTR("IS_PLAYING"))) {
    MediaPlayer.requestPlayingState();
  } else if(SerialServer.isBufferEqualTo_P(PSTR("LIST"))) {
    MediaPlayer.requestPlaylist();
  } 
}
 
void receivedResponse(String request, String response, bool success) {
  Serial.println("Received response: " + response + " to request: " + request);
}

void setup() {
  Ethernet.begin(mac,ip);
    
  // start the serial SERVER library (taking in commands from serial monitor):
  SerialServer.begin(115200);
  SerialServer.setHandleIncomingLine(handleSerialIncoming);  // Put only the name of the function
  SerialServer.serialOutput(3);
  SerialServer.enableEOLTimeout();  // Calling this without parameters sets EOL Timeout to 2ms which is enough for 9600 baud and up. Use only if the serial client (like Arduinos serial monitor) doesn't by itself send a <cr> token.
  Serial << F("Type stuff in the serial monitor to send over telnet...\n");  
  Serial << F("\nSupported commands:\n\n");
  Serial << F("LIST\n");
  Serial << F("IS_PLAYING\n\n");

  
  W5100.setRetransmissionTime(1000);  // Milli seconds
  W5100.setRetransmissionCount(1);
  
  sharedClient.serialOutput(false);
  
  MediaPlayer.begin(sharedClient, 1, serverip);
  MediaPlayer.serialOutput(2);
  MediaPlayer.setResponseCallback(receivedResponse);
  
  // In order to be able to start playing, the list must be fetched.
  MediaPlayer.requestPlaylist();
}

long a = millis();
void loop() {
  if(millis() - a > 10000) {
    //MediaPlayer.playFile("\"RED30sec.mp4\"", true);
    a = millis();
    Serial.print("freeMemory()=");
    Serial.println(freeMemory());
  }
  SerialServer.runLoop();
  MediaPlayer.runLoop();
}
