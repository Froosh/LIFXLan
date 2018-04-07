enum LifxDeviceType {
    Any
    Light
    MultiZone
    Tile
    Chain
}

class LifxLanDevice {
    [LifxDeviceType]
    $DeviceType

    [string]
    $Name
}
