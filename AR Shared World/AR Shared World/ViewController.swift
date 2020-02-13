//
//  ViewController.swift
//  AR Shared World
//
//  Created by Pedro Giuliano Farina on 12/02/20.
//  Copyright © 2020 Pedro Giuliano Farina. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, MultipeerHandler {

    //Foi encontrado um peer, devemos convidar a conectar?
    func peerDiscovered(_ id: MCPeerID) -> Bool {
        return true
    }

    //Um convite foi recebido, devo aceitar?
    func peerReceivedInvitation(_ id: MCPeerID) -> Bool {
        return true
    }

    //Recebemos dados de algum dispositivo multipeer, o que fazer?
    func receivedData(_ data: Data, from peerID: MCPeerID) {
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) {
            sceneView.session.update(with: collaborationData)
            return
        }
    }

    //Houve alguma alteração na sessão AR, o que fazer?
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
        if !multipeerSession.connectedPeers.isEmpty {
            guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
                else { fatalError("Unexpectedly failed to encode collaboration data.") }
            let dataIsCritical = data.priority == .critical
            multipeerSession.sendToAllPeers(encodedData, reliably: dataIsCritical)
        }
    }


    @IBOutlet var sceneView: ARSCNView!

    var configuration: ARWorldTrackingConfiguration?

    lazy var multipeerSession = MultipeerController(serviceType: "ar-sharedWorld", handler: self)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = ARWorldTrackingConfiguration()
        //Se o mundo será colaborativo
        configuration.isCollaborationEnabled = true
        //O tipo de luz, automática = luz do mundo real
        configuration.environmentTexturing = .automatic
        self.configuration = configuration

        sceneView.session.run(configuration)
        sceneView.delegate = self
        sceneView.session.delegate = self
        let scene = SCNScene()
        sceneView.scene = scene

        //Não apagar a tela automaticamente
        UIApplication.shared.isIdleTimerDisabled = true

        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(gesture)
    }

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: sceneView)

        //Criando um ray tracing para definir o ponto em que o usuário tocou a tela em relação ao mundo real leia mais em: https://developer.apple.com/documentation/arkit/ray-casting_and_hit-testing
        if let query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal),
            let firstResult = sceneView.session.raycast(query).first {

            //Adicionando uma ancora com um identificador no lugar tocado e adicionando a ancora na cena
            let anchor = ARAnchor(name: "Anchor for object placement", transform: firstResult.worldTransform)
            sceneView.session.add(anchor: anchor)
        } else {
            print("Warning: Object placement failed.")
        }
    }

    //Uma vez que a ancora é adicionada a cena, também é criado um node que representará essa ancora na cena do SceneKit
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if anchor.name == "Anchor for object placement" {
            let box = SCNNode(geometry: SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0))
            box.position = SCNVector3(0, 0.05, 0)

            //Então adicionamos um node ao node atribuido a ancora
            node.addChildNode(box)
        }
    }
}
