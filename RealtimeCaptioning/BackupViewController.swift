//
//  ViewController.swift
//  RealtimeCaptioning
//
//  Created by An Tran on 08.05.19.
//  Copyright © 2019 An Tran. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import Speech

class ViewController: UIViewController {

    let audioEngine = AVAudioEngine()
    let speechRecognizer = SFSpeechRecognizer()
    let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask?

    var player: AVPlayer?
    var playerItem: AVPlayerItem! = nil
    var audioProcessingFormat:  AudioStreamBasicDescription?

    // looks like you can't stop an audio tap synchronously, so it's possible for your clientInfo/tapStorage
    // refCon/cookie object to go out of scope while the tap process callback is still being called.
    // As a solution wrap your object of interest as a weak reference that can be guarded against
    // inside an object (cookie) whose scope we do control.
    class TapCookie {
        weak var content: AnyObject?

        init(content: AnyObject) {
            self.content = content
        }

        deinit {
            print("TapCookie deinit")    // should appear after finalize
        }
    }

    let tapInit: MTAudioProcessingTapInitCallback = {
        (tap, clientInfo, tapStorageOut) in

        // Make tap storage the same as clientInfo. I guess you might want them to be different.
        tapStorageOut.pointee = clientInfo
    }

    let tapProcess: MTAudioProcessingTapProcessCallback = {
        (tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut) in
        print("callback \(tap), \(numberFrames), \(flags), \(bufferListInOut), \(numberFramesOut), \(flagsOut)\n")

        let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
        if noErr != status {
            print("get audio: \(status)\n")
        }

        let cookie = Unmanaged<TapCookie>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
        guard let cookieContent = cookie.content else {
            print("Tap callback: cookie content was deallocated!")
            return
        }

        let viewControllerRef = cookieContent as! ViewController
        print("cookie content \(viewControllerRef)")

        viewControllerRef.processAudioData(audioData: bufferListInOut, framesNumber: UInt32(numberFrames))
    }

    let tapFinalize: MTAudioProcessingTapFinalizeCallback = {
        (tap) in
        print("finalize \(tap)\n")

        // release cookie
        Unmanaged<TapCookie>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
    }

    var tracksObserver: NSKeyValueObservation? = nil
    var statusObservation: NSKeyValueObservation? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func didTapPermissionButton(_ sender: Any) {
        SFSpeechRecognizer.requestAuthorization {
            [unowned self] (authStatus) in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            case .denied:
                print("Speech recognition authorization denied")
            case .restricted:
                print("Not available on this device")
            case .notDetermined:
                print("Not determined")
            }
        }
    }

    @IBAction func didTapPlayButton(_ sender: Any) {
        //let videoURL = URL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")
        //let videoURL = URL(string: "https://www.americanrhetoric.com/mp3clips/barackobama/barackobamasenatespeechohiovotecounting.mp3")!
        let videoURL = URL(string: "https://realm.wistia.com/medias/u3xprtodqi")!
        playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
        player?.play()

        self.tracksObserver = playerItem.observe(\AVPlayerItem.tracks) { [unowned self] item, change in
            print("tracks change \(item.tracks)")
            print("asset tracks (btw) \(item.asset.tracks)")
            self.installTap(playerItem: self.playerItem)
        }

        self.statusObservation = playerItem.observe(\AVPlayerItem.status) { [unowned self] object, change in
            print("playerItem status change \(object.status.rawValue)")
            if object.status == .readyToPlay {
                self.player?.play()

                // indirectly stop and dealloc tap to test finalize and cookie code.
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    print("\"deallocating\" tap")
                    self.playerItem = nil
                    self.player = nil
                }

            }
        }

        recognitionRequest.shouldReportPartialResults = true  //6

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in  //7
            if let result = result {
                print(result.bestTranscription.formattedString)
            }
        })

//        let recordingFormat = inputNode.outputFormat(forBus: 0)  //11
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
//            self.recognitionRequest?.append(buffer)
//        }
    }

    func installTap(playerItem: AVPlayerItem) {
        let cookie = TapCookie(content: self)

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(cookie).toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: nil,
            unprepare: nil,
            process: tapProcess)

        var tap: Unmanaged<MTAudioProcessingTap>?
        let err = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap)
        assert(noErr == err);

        let audioTrack = playerItem.asset.tracks(withMediaType: AVMediaType.audio).first!
        let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
        inputParams.audioTapProcessor = tap?.takeRetainedValue()

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [inputParams]

        playerItem.audioMix = audioMix
    }

    func processAudioData(audioData: UnsafeMutablePointer<AudioBufferList>, framesNumber: UInt32) {
        var sbuf: CMSampleBuffer?
        var status : OSStatus?
        var format: CMFormatDescription?

        var buffer: AudioBuffer
        var audioBufferListPtr = audioData.memory
        for i in 0 ..< Int(framesNumber) {
            buffer = audioBufferListPtr.mBuffers
        }
//        //FORMAT
//        //        var audioFormat = self.audioProcessingFormat//self.audioProcessingFormat?.pointee
//        guard var audioFormat = self.audioProcessingFormat else {
//            return
//        }
//        status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &audioFormat, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
//        if status != noErr {
//            print("Error CMAudioFormatDescriptionCreater :\(String(describing: status?.description))")
//            return
//        }
//
//
//        print(">> Audio Buffer mSampleRate:\(Int32(audioFormat.mSampleRate))")
//        var timing = CMSampleTimingInfo(duration: CMTimeMake(value: 1, timescale: Int32(audioFormat.mSampleRate)), presentationTimeStamp: self.player!.currentTime(), decodeTimeStamp: CMTime.invalid)
//
//
//        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
//                                      dataBuffer: nil,
//                                      dataReady: Bool(truncating: 0),
//                                      makeDataReadyCallback: nil,
//                                      refcon: nil,
//                                      formatDescription: format,
//                                      sampleCount: CMItemCount(framesNumber),
//                                      sampleTimingEntryCount: 1,
//                                      sampleTimingArray: &timing,
//                                      sampleSizeEntryCount: 0, sampleSizeArray: nil,
//                                      sampleBufferOut: &sbuf);
//        if status != noErr {
//            print("Error CMSampleBufferCreate :\(String(describing: status?.description))")
//            return
//        }
//        status =   CMSampleBufferSetDataBufferFromAudioBufferList(sbuf!,
//                                                                  blockBufferAllocator: kCFAllocatorDefault ,
//                                                                  blockBufferMemoryAllocator: kCFAllocatorDefault,
//                                                                  flags: 0,
//                                                                  bufferList: audioData)
//        if status != noErr {
//            print("Error cCMSampleBufferSetDataBufferFromAudioBufferList :\(String(describing: status?.description))")
//            return
//        }
//
//        let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sbuf!);
//        print(" audio buffer at time: \(currentSampleTime)")
////        self.delegate?.videoFrameRefresh(sampleBuffer: sbuf!)
    }

    func processAudioBuffer(buffer: CMSampleBuffer) {
        // AVAudioPCMBuffer
        self.recognitionRequest.append(buffer)
    }

}
