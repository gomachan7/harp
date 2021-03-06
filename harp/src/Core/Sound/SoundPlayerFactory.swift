import Foundation
import OpenAL
import RxSwift

fileprivate let alTrue: ALboolean = Int8(AL_TRUE)
fileprivate let alFalse: ALboolean = Int8(AL_FALSE)
fileprivate let alNone: ALuint = ALuint(AL_NONE)

final class SoundPlayerFactory {

  // This class is Singleton
  // If shared object is nil, try to instantiate because of failable initializer.

  static private var instance = SoundPlayerFactory()

  static var shared: SoundPlayerFactory? {
    if instance == nil {
      instance = SoundPlayerFactory()
    }

    return instance
  }

  private init?() {
    let isInitialized = alureInitDevice(nil, nil)

    guard isInitialized == alTrue else {
      Logger.error("Failed to init device")
      return nil
    }
  }

  deinit {
    alureShutdownDevice()
  }

  // MARK: - internal

  func makePlayer<T>(keyAndFileFullPath: [T: String]) -> Observable<SoundPlayer<T>> {

    return Observable.create { observer in

      var keyAndSources = [T: ConcreteSoundSource]()
      var errorToRead = [T: String]()

      keyAndFileFullPath.forEach {
        guard let source = ConcreteSoundSource(fullFilePath: $1) else {
          errorToRead[$0] = $1
          return
        }

        keyAndSources[$0] = source
      }

      let player = SoundPlayer(keyAndSources: keyAndSources)

      observer.onNext(player)

      if errorToRead.count > 0 {
        let error = NSError(domain: "harp.SoundPlayerFactory", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to load \(errorToRead.count) files. \(errorToRead)"])
        observer.onError(error)
      }

      return Disposables.create()
    }
  }

}

// MARK: - fileprivate

fileprivate final class ConcreteSoundSource: SoundSource {
  private var buffer: ALuint
  private var source: ALuint
  private let fullFilePath: String
  
  static private let extsToTryToLoad = [".ogg", ".mp3", ".wav"]

  init?(fullFilePath: String) {
    // firstly, try to load with original ext.
    var buffer = alureCreateBufferFromFile(fullFilePath)
    
    // on error to load, try to load with anothor ext
    if buffer == alNone {
      let originalExt = fullFilePath.pregMatche(pattern: "\\.[a-zA-Z0-9]+$")?.last ?? ""
      let exts = ConcreteSoundSource.extsToTryToLoad.filter { $0 != originalExt }
      
      // Retry to load
      for ext in exts {
        let fullFilePathWithExt = fullFilePath.pregReplace(pattern: "\\.[a-zA-Z0-9]+$", with: ext)
        buffer = alureCreateBufferFromFile(fullFilePathWithExt)
                
        if buffer != alNone {
          Logger.error("Load success \(fullFilePathWithExt)")
          break
        }
      }
      
      // on error
      if buffer == alNone {
        Logger.error("Failed to load \(fullFilePath)")
        return nil
      }
    }

    var source: ALuint = 0
    alGenSources(1, &source)

    alSourcei(source, AL_BUFFER, ALint(buffer))

    self.buffer = buffer
    self.source = source
    self.fullFilePath = fullFilePath
  }

  deinit {
    alureStopSource(source, alTrue)
    alDeleteSources(1, &source)
    alDeleteBuffers(1, &buffer)
  }

  // MARK: - SoundPlayer

  func play() {
    if alurePlaySource(source, nil, nil) != alTrue {
      Logger.info("Failed to play source \(self.fullFilePath)")
    }
  }

  func stop() {
    if alureStopSource(source, alFalse) != alTrue {
      Logger.info("Failed to stop source \(self.fullFilePath)")
    }
  }

  func pause() {
    if alurePauseSource(source) != alTrue {
      Logger.info("Failed to pause source \(self.fullFilePath)")
    }
  }

  func setOffset(second: Float) {
    alSourcef(source, AL_SEC_OFFSET, second)
  }

  func setShouldLooping(_ shouldLoop: Bool) {
    alSourcei(source, AL_LOOPING, shouldLoop ? 1 : 0)
  }

  func setVolume(_ value: Float) {
    alSourcef(source, AL_GAIN, value)
  }
}
