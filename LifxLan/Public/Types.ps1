enum LifxDeviceType {
    Any
    Light
    MultiZone
    Tile
    Chain
}

class LifxLanDeviceVersion {
    [uint32] $Vendor
    [uint32] $Product
    [uint32] $Version
}

class LifxLanDevice {
    [uint64] $Identifier
    [System.Net.IPEndPoint] $IPEndPoint
    [LifxServiceType[]] $ServiceTypes = @()
    [LifxLanDeviceVersion] $Hardware
    [string] $Label
    [string] $Location
    [string] $Group
}
