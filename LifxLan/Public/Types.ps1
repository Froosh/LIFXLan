enum LifxDeviceType {
    Any
    Light
    MultiZone
    Tile
    Chain
}

class LifxLanDevice {
    [uint64] $Identifier
    [System.Net.IPEndPoint] $IPEndPoint
    [LifxServiceType[]] $ServiceTypes = @()
}
