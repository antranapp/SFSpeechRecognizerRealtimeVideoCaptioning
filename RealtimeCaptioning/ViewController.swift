//
//  ViewController.swift
//  RealtimeCaptioning
//
//  Created by An Tran on 08.05.19.
//  Copyright © 2019 An Tran. All rights reserved.
//

import UIKit
import Speech
import AVFoundation
import Foundation

class ViewController: UIViewController {

    @IBOutlet weak var captionLabel: UILabel!

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?


    private var player = AVQueuePlayer()
    private var playerItem: AVPlayerItem!
    private let playerLayer = AVPlayerLayer()

    private var tap: MYAudioTapProcessor!

    @IBOutlet weak var captionsLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    @IBAction func didTapPermissionButton(_ sender: UIButton) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
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

    @IBAction func didTapPlayButton(_ sender: UIButton) {
        print("Start playing....")

        // URL
//        guard let videoURL = URL(string: "http://www.obamadownloads.com/videos/dnc-2004-speech.mp4") else {
//            return
//        }
//        playerItem = AVPlayerItem(url: videoURL)
//        guard let itemTrack = playerItem.tracks.first else {
//            return
//        }
//        guard let audioTrack = itemTrack.assetTrack else {
//            return
//        }

        // Asset
        guard let url = Bundle.main.url(forResource: "video2", withExtension: "mp4") else {
            print("can't get url")
            return
        }
        let asset = AVURLAsset(url: url)
        guard let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first else {
            print("can't get audioTrack")
            return
        }
        playerItem = AVPlayerItem(asset: asset)

        // Taken from https://github.com/zats/SpeechRecognition
        tap = MYAudioTapProcessor(audioAssetTrack: audioTrack)
        tap.delegate = self

        player.insert(playerItem, after: nil)
        player.currentItem?.audioMix = tap.audioMix
        player.play()

        // Player view
        let playerView: UIView! = view
        playerLayer.player = player
        playerLayer.frame = playerView.bounds
        playerView.layer.insertSublayer(playerLayer, at: 0)

        self.setupRecognition()
    }

    private func setupRecognition() {
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        // we want to get continuous recognition and not everything at once at the end of the video
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.captionLabel.text = result?.bestTranscription.formattedString

            // once in about every minute recognition task finishes so we need to set up a new one to continue recognition
            if result?.isFinal == true {
                self?.recognitionRequest = nil
                self?.recognitionTask = nil

                self?.setupRecognition()
            }
        }
        self.recognitionRequest = recognitionRequest
    }

    override func viewDidLayoutSubviews() {
        playerLayer.frame = view.bounds
    }
}

extension ViewController: MYAudioTabProcessorDelegate {
    // getting audio buffer back from the tap and feeding into speech recognizer
    func audioTabProcessor(_ audioTabProcessor: MYAudioTapProcessor!, didReceive buffer: AVAudioPCMBuffer!) {
        recognitionRequest?.append(buffer)
    }
}
