/* -LICENSE-START-
** Copyright (c) 2012 Blackmagic Design
**
** Permission is hereby granted, free of charge, to any person or organization
** obtaining a copy of the software and accompanying documentation covered by
** this license (the "Software") to use, reproduce, display, distribute,
** execute, and transmit the Software, and to prepare derivative works of the
** Software, and to permit third-parties to whom the Software is furnished to
** do so, all subject to the following:
** 
** The copyright notices in the Software and this entire statement, including
** the above license grant, this restriction and the following disclaimer,
** must be included in all copies of the Software, in whole or in part, and
** all derivative works of the Software, unless such copies or derivative
** works are solely in the form of machine-executable object code generated by
** a source language processor.
** 
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
** FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
** SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
** FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
** ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
** DEALINGS IN THE SOFTWARE.
** -LICENSE-END-
*/

#pragma once

#include "BMDSwitcherAPI.h"


@class MediaPoolWatcher;



void  setUploading();
void  setDownloading();

// This file contains Callback and Monitor classes.
//
// Callback classes implement SDK callback interfaces to forward
// callback results to the main thread where it is safe to update the UI.
// performSelectorOnMainThread methods are used to acheive this.
//
// Monitor classes register callbacks against SDK interfaces.

// Media player callback class
class MediaPlayerCallback : public IBMDSwitcherMediaPlayerCallback
{
public:
	MediaPlayerCallback(MediaPoolWatcher* uiDelegate);

	// IUnknown
	HRESULT		QueryInterface(REFIID iid, LPVOID* ppv);
	ULONG		AddRef(void);
	ULONG		Release(void);
	
	// IBMDSwitcherMediaPlayerCallback
	HRESULT		SourceChanged(void);
	HRESULT		PlayingChanged(void);
	HRESULT		LoopChanged(void);
	HRESULT		AtBeginningChanged(void);
	HRESULT		ClipFrameChanged(void);

private:
	~MediaPlayerCallback(); // Call Release

	MediaPoolWatcher*	mUIDelegate;
	int								mRefCount;
};

// Class for monitoring changes to a media player interface
class MediaPlayerMonitor
{
public:
	MediaPlayerMonitor(MediaPoolWatcher* uiDelegate);
	~MediaPlayerMonitor();
	
	void setMediaPlayer(IBMDSwitcherMediaPlayer* mediaPlayer);
	void flush();

private:
	MediaPlayerCallback*		mCallback;
	IBMDSwitcherMediaPlayer*	mMediaPlayer;
};

// Stills callback class
class StillsCallback : public IBMDSwitcherStillsCallback
{
public:
	StillsCallback(MediaPoolWatcher* uiDelegate);

public:
	// IUnknown
	HRESULT		QueryInterface(REFIID iid, LPVOID* ppv);
	ULONG		AddRef(void);
	ULONG		Release(void);
	
	// IBMDSwitcherStillsCallback
	HRESULT		Notify(BMDSwitcherMediaPoolEventType eventType, IBMDSwitcherFrame *frame, int32_t index);

private:
	~StillsCallback(); // Call Release()

	MediaPoolWatcher*	mUIDelegate;
	int32_t							mRefCount;
};

// Class for monitoring changes to a stills interface
class StillsMonitor
{
public:
	StillsMonitor(MediaPoolWatcher* uiDelegate);
	~StillsMonitor();

	void setStills(IBMDSwitcherStills* stills);
	void flush();

private:
	StillsCallback*			mCallback;
	IBMDSwitcherStills*		mStills;
};

// Clip callback class
class ClipCallback : public IBMDSwitcherClipCallback
{
public:
	ClipCallback(MediaPoolWatcher* uiDelegate);

public:
	// IUnknown
	HRESULT		QueryInterface(REFIID iid, LPVOID* ppv);
	ULONG		AddRef(void);
	ULONG		Release(void);
	
	// IBMDSwitcherClipCallback
	HRESULT		Notify(BMDSwitcherMediaPoolEventType eventType,
					   IBMDSwitcherFrame *frame,
					   int32_t frameIndex,
					   IBMDSwitcherAudio *audio,
					   int32_t clipIndex);
private:
	~ClipCallback(); // Call Release()

	MediaPoolWatcher*	mUIDelegate;
	int32_t							mRefCount;
};

// Class for monitoring changes to a clip interface
class ClipMonitor
{
public:
	ClipMonitor(MediaPoolWatcher* uiDelegate);
	~ClipMonitor();

	void setClip(IBMDSwitcherClip* clip);
	void flush();

private:
	ClipCallback*			mCallback;
	IBMDSwitcherClip*		mClip;
};

// Lock callback class used for obtaining lock as required
// for transfers and used in StillTransfer class.
class LockCallback : public IBMDSwitcherLockCallback
{
public:
	LockCallback(MediaPoolWatcher* uiDelegate, int clipIndex = -1); // do not set clipIndex for stills

	// IUnknown
 	HRESULT		QueryInterface(REFIID iid, LPVOID* ppv);
	ULONG		AddRef(void);
	ULONG		Release(void);

	// IBMDSwitcherLockCallback
	HRESULT		Obtained();

private:
	MediaPoolWatcher*	mUIDelegate;
	int32_t							mRefCount;
	int								mClipIndex;
};

// Switcher callback class
class SwitcherCallback : public IBMDSwitcherCallback
{
public:
	SwitcherCallback(MediaPoolWatcher* uiDelegate);
	
	// IUnknown
	HRESULT		QueryInterface(REFIID iid, LPVOID* ppv);
	ULONG		AddRef(void);
	ULONG		Release(void);
	
	// IBMDSwitcherCallback
	HRESULT		Notify(BMDSwitcherEventType eventType);
	HRESULT		Disconnected(void);

private:
	~SwitcherCallback(); // Call Release()
    
	MediaPoolWatcher*	mUIDelegate;
	int32_t							mRefCount;
};

// Class for monitoring changes to a switcher interface
class SwitcherMonitor
{
public:
	SwitcherMonitor(MediaPoolWatcher* uiDelegate);
	~SwitcherMonitor();

	void setSwitcher(IBMDSwitcher* switcher);

private:
	SwitcherCallback*	mCallback;
	IBMDSwitcher*		mSwitcher;
};
