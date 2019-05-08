Heavily inspired from https://github.com/zats/SpeechRecognition.
Goal: After seeing Google i/o 2019 where google introduces Live Transcription of videos, I'm asking myself if we can do the same in iOS. The simplest option is to use `SFSpeechRecognizer` to tap into audio stream of a video and transcribe the audio buffer. After some googling I found something that I can put together to a simple demo. Naturally Google's solution is a lot superior to what iOS can: clean API, offline, multiple languages etc... Hopefully Apple will introduce something similar in their next WWDC 2019.

Next step: Swift version of MTAudioProcessingTap

[Youtube Demo](https://youtu.be/CP9o_TVYDtQ)

Some related links to the topic:
* https://stackoverflow.com/questions/53636698/mtaudioprocessingtap-exc-bad-access-doesnt-always-fire-the-finalize-callback#53637508
* https://github.com/gchilds/MTAudioProcessingTap-in-Swift
* https://gist.github.com/omarojo/03d08165a1a7962cb30c17ec01f809a3
