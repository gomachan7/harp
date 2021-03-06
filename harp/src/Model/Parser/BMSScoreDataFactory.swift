import Foundation

final class BMSScoreDataFactory {

  // MARK: - internal

  static func makeFrom(headerData: BMSHeaderData,
                       channelData: [BMSChannelData]) -> BMSScoreData {

    let barLength = channelData.count
    var scoreData = BMSScoreData()

    for bar in 0..<barLength {

      channelData[bar].playWav.forEach {
        storeEventData(to: &(scoreData.playWav),
                       baseTick: channelData[bar].startTick,
                       barTickCount: channelData[bar].barTickCount,
                       data: $0,
                       maker: { BMSBarEventData(tick: $0, key: $1) })
      }

      storeChangeBpmData(to: &(scoreData.changeExBpm),
                         baseTick: channelData[bar].startTick,
                         barTickCount: channelData[bar].barTickCount,
                         data: channelData[bar].changeBpm)

      storeEventData(to: &(scoreData.changeBaseLayer),
                     baseTick: channelData[bar].startTick,
                     barTickCount: channelData[bar].barTickCount,
                     data: channelData[bar].changeBaseLayer,
                     maker: { BMSBarEventData(tick: $0, key: $1) })

      storeEventData(to: &(scoreData.changePoorLayer),
                     baseTick: channelData[bar].startTick,
                     barTickCount: channelData[bar].barTickCount,
                     data: channelData[bar].changePoorLayer,
                     maker: { BMSBarEventData(tick: $0, key: $1) })

      storeChangeExBpmData(to: &(scoreData.changeExBpm),
                           header: headerData,
                           baseTick: channelData[bar].startTick,
                           barTickCount: channelData[bar].barTickCount,
                           data: channelData[bar].changeExBpm)

      storeEventData(to: &(scoreData.stopPlay),
                     baseTick: channelData[bar].startTick,
                     barTickCount: channelData[bar].barTickCount,
                     data: channelData[bar].stopPlay,
                     maker: { BMSBarEventData(tick: $0, key: $1) })

      channelData[bar].notes.forEach { k, v in
        storeEventData(to: &(scoreData.notes),
                       baseTick: channelData[bar].startTick,
                       barTickCount: channelData[bar].barTickCount,
                       data: v,
                       maker: { BMSBarNoteData(tick: $0, key: $1,
                                               trait: k) })
      }
    }

    // Apply long notes(can specify long notes with 2 way)
    applyChannelLongNoteData(score: &scoreData)
    applyLnobjLongNoteData(score: &scoreData, lnobjMark: headerData.lnobj)

    sortBarDataOrderByTickAsc(&scoreData)

    return scoreData
  }

  // MARK: - private

  static private func sortBarDataOrderByTickAsc(_ scoreData: inout BMSScoreData) {

    scoreData.notes.sort { $0.0.tick < $0.1.tick }
    scoreData.playWav.sort { $0.0.tick < $0.1.tick }
    scoreData.changeExBpm.sort { $0.0.tick < $0.1.tick }
    scoreData.changeBaseLayer.sort { $0.0.tick < $0.1.tick }
    scoreData.changePoorLayer.sort { $0.0.tick < $0.1.tick }
    scoreData.stopPlay.sort { $0.0.tick < $0.1.tick }
  }

  static private func storeChangeBpmData(to target: inout [BMSBarBPMEventData],
                                         baseTick: Int, barTickCount: Int, data: String?) {
    guard
      let data = data,
      let dataArray = data.splitBy(length: 2) else {
        return
    }

    let dataLength = dataArray.count

    dataArray.enumerated().forEach { i, v in
      guard
      v != Config.BMS.keyForRest,
        let intBpm = Int(v, radix: 16) else {
          return
      }

      let posInBar = Double(i) / Double(dataLength)
      let tick = baseTick + Int(Double(barTickCount) * posInBar)

      let bpm = Double(intBpm)

      // Overrwite if exist on same tick already
      if let index = target.index(where: { $0.tick == tick }) {
        target[index].value = bpm
      } else {
        target.append(BMSBarBPMEventData(tick: tick, value: bpm))
      }
    }
  }

  static private func storeChangeExBpmData(to target: inout [BMSBarBPMEventData],
                                           header: BMSHeaderData,
                                           baseTick: Int, barTickCount: Int, data: String?) {
    guard
      let data = data,
      let dataArray = data.splitBy(length: 2) else {
        return
    }

    let dataLength = dataArray.count

    dataArray.enumerated().forEach { i, v in
      guard
      v != Config.BMS.keyForRest,
        let key = Int(v, radix: 36),
        let bpm = header.exBpm[key] else {
          return
      }

      let posInBar = Double(i) / Double(dataLength)
      let tick = baseTick + Int(Double(barTickCount) * posInBar)

      // Overrwite if exist on same tick already
      if let index = target.index(where: { $0.tick == tick }) {
        target[index].value = bpm
      } else {
        target.append(BMSBarBPMEventData(tick: tick, value: bpm))
      }
    }
  }

  static private func storeEventData<T>(to target: inout [T],
                                        baseTick: Int, barTickCount: Int, data: String?,
                                        maker: (_ tick: Int, _ key: Int) -> T) {
    guard
      let data = data,
      let dataArray = data.splitBy(length: 2) else {
        return
    }

    let dataLength = dataArray.count
    let keyForRest = Int(Config.BMS.keyForRest, radix: 36)!

    dataArray.enumerated().forEach { i, v in
      let posInBar = Double(i) / Double(dataLength)
      let tick = baseTick + Int(Double(barTickCount) * posInBar)

      guard let key = Int(v, radix: 36),
        key != keyForRest else {
          return
      }

      target.append(maker(tick, key))
    }
  }
  
  static private func applyChannelLongNoteData(score: inout BMSScoreData) {
    score.notes.sort { $0.0.tick < $0.1.tick }
    
    var applied = [BMSBarNoteData]()
    
    LaneType.values.forEach { lane in

      var inLongNoteRange = false

      score.notes
        .filter { $0.trait.lane == lane }.forEach {

        if $0.trait.type == .longStart {
          // Open or close long notes
          var longNote = $0
          longNote.trait.type = inLongNoteRange ? .longEnd : .longStart
          applied.append(longNote)
          
          inLongNoteRange = !inLongNoteRange
          return
        }
        
        // Through notes in range of long notes
        if !inLongNoteRange {
          applied.append($0)
        }
      }
    }
    
    score.notes = applied.sorted { $0.0.tick < $0.1.tick }
  }
  
  static private func applyLnobjLongNoteData(score: inout BMSScoreData, lnobjMark: Int?) {
    guard let longEndMark = lnobjMark else {
      return
    }
    
    var applied = [BMSBarNoteData]()
    
    LaneType.values.forEach { lane in
      
      var inLongNoteRange = false

      score.notes
        .filter { $0.trait.lane == lane }
        .sorted { $0.0.tick > $0.1.tick }.forEach {

          // Time series is reversed to detect end mark first
          if !inLongNoteRange && $0.key == longEndMark {
            var longEndNote = $0
            longEndNote.trait.type = .longEnd
            applied.append(longEndNote)
            
            inLongNoteRange = true
            return
          }
          
          if inLongNoteRange && $0.trait.type == .visible {
            var longStartNote = $0
            longStartNote.trait.type = .longStart
            applied.append(longStartNote)

            inLongNoteRange = false
            return
          }

          // Through notes in range of long notes
          if !inLongNoteRange {
            applied.append($0)
          }
      }
    }

    score.notes = applied.sorted { $0.0.tick < $0.1.tick }
  }
}
