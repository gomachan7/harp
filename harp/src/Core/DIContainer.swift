import Foundation
import Swinject
import SpriteKit

struct DIContainer {
  static func scene<Scene: SKScene>(_ scene: Scene.Type) -> Scene {
    return container.resolve(scene)!
  }
}

fileprivate let container = Container { c in
  
  c.register(PlayScene.self) { _ in
    let m = PlayModel()
    let v = PlayView()
    let c = PlayController(model: m, view: v)
    let scene = PlayScene(model: m, view: v, controller: c)
    
    return scene
  }
}
