import Capacitor

final class ArchiveBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        bridge?.registerPluginInstance(ArchiveNativePlugin())
    }
}
