enum LifxMesssageType {
    GetService = 2
    StateService = 3
    GetHostInfo = 12
    StateHostInfo = 13
    GetHostFirmware = 14
    StateHostFirmware = 15
    GetWifiInfo = 16
    StateWifiInfo = 17
    GetWifiFirmware = 18
    StateWifiFirmware = 19
    GetPower = 20
    SetPower = 21
    StatePower = 22
    GetLabel = 23
    SetLabel = 24
    StateLabel = 25
    GetVersion = 32
    StateVersion = 33
    GetInfo = 34
    StateInfo = 35
    Acknowledgement = 45
    GetLocation = 48
    SetLocation = 49
    StateLocation = 50
    GetGroup = 51
    SetGroup = 52
    StateGroup = 53
    EchoRequest = 58
    EchoResponse = 59
    LightGet = 101
    LightSetColor = 102
    LightSetWaveform = 103
    LightState = 107
    LightGetPower = 116
    LightSetPower = 117
    LightStatePower = 118
    LightSetWaveformOptional = 119
    LightGetInfrared = 120
    LightStateInfrared = 121
    LightSetInfrared = 122
    MultiZoneSetColorZones = 501
    MultiZoneGetColorZones = 502
    MultiZoneStateZone = 503
    MultiZoneStateMultiZone = 506
    TileGetDeviceChain = 701
    TileStateDeviceChain = 702
    TileSetUserPosition = 703
    TileGetTileState64 = 707
    TileStateTileState64 = 711
    TileSetTileState64 = 715
}

enum LifxServiceType {
    UDP = 1
    Type5 = 5 # Multicast?
}

enum LifxPowerLevel {
    StandBy = 0
    Enabled = 65535
}


class LifxHeader {
    static hidden [uint16] $HEADER_SIZE_BYTES = 36

    #Region Frame Header [8 Bytes]
    [uint16] $Size = [LifxHeader]::HEADER_SIZE_BYTES            # 16 bits [0..1]
    [byte] $Origin = 0                                          # 2 bits [2..       # Must be 0
    [bool] $Tagged = $false                                     # 1 bit ..
    [bool] $Addressable = $true                                 # 1 bit ..          # Must be 1
    [uint16] $Protocol = 1024                                   # 12 bits ..3]      # Must be 1024
    [uint32] $Source = $PID                                     # 32 bits [4..7]
    #EndRegion Frame Header [8 Bytes]

    #Region Frame Address [16 Bytes]
    [uint64] $Target = 0                                        # 64 bits [8..15]
    hidden [byte[]] $Reserved1 = 0, 0, 0, 0, 0, 0               # 48 bits [16..21]  # LIFXV2
    hidden [byte] $Reserved2 = 0                                # 6 bits [22..
    [bool] $AcknowledgementRequired = $false                    # 1 bit ..
    [bool] $ResponseRequired = $false                           # 1 bit ..22]
    [byte] $Sequence = 0                                        # 8 bits [23]
    #EndRegion Frame Address [16 Bytes]

    #Region Protocol Header [12 Bytes]
    [datetime] $Timestamp = [datetime]::Now                     # 64 bits [24..31] [uint64] # Nanoseconds since unix epoch (utc)
    [LifxMesssageType] $Type = [LifxMesssageType]::GetService   # 16 bits [32..33] [uint16]
    hidden [uint16] $Reserved4 = 0                              # 16 bits [34..35]
    #EndRegion Protocol Header [12 Bytes]

    LifxHeader() {
    }

    LifxHeader([byte[]] $HeaderData) {
        $MemoryStream = [System.IO.MemoryStream]::new($HeaderData)
        $BinaryReader = [System.IO.BinaryReader]::new($MemoryStream)

        #Region Frame Header
        $this.Size = $BinaryReader.ReadUInt16()

        $FrameHeaderStruct = $BinaryReader.ReadUInt16()
        $this.Origin = ($FrameHeaderStruct -shr 14) -band 3 # 2^2 - 1
        $this.Tagged = ($FrameHeaderStruct -shr 13) -band 1
        $this.Addressable = ($FrameHeaderStruct -shr 12) -band 1
        $this.Protocol = $FrameHeaderStruct -band 4095 # 2^12 - 1

        $this.Source = $BinaryReader.ReadUInt32()
        #EndRegion Frame Header

        #Region Frame Address
        $this.Target = $BinaryReader.ReadUInt64()
        $this.Reserved1 = $BinaryReader.ReadBytes(6)

        $FrameAddressStruct = $BinaryReader.ReadByte()
        $this.Reserved2 = ($FrameAddressStruct -shr 2) -band 63 # 2^6 - 1
        $this.AcknowledgementRequired = ($FrameAddressStruct -shr 1) -band 1
        $this.ResponseRequired = $FrameAddressStruct -band 1

        $this.Sequence = $BinaryReader.ReadByte()
        #EndRegion Frame Address

        #Region Protocol Header
        $this.Timestamp = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc).AddTicks($BinaryReader.ReadUInt64() / 100).ToLocalTime()
        $this.Type = [LifxMesssageType] $BinaryReader.ReadUInt16()
        $this.Reserved4 = $BinaryReader.ReadUInt16()
        #EndRegion Protocol Header
    }

    [byte[]] GetHeaderBytes() {
        $MemoryStream = [System.IO.MemoryStream]::new()
        $BinaryWriter = [System.IO.BinaryWriter]::new($MemoryStream)

        #Region Frame Header
        $BinaryWriter.Write($this.Size)

        [uint16] $FrameHeaderStruct = 0
        $FrameHeaderStruct += ($this.Origin -band 3) -shl 14
        $FrameHeaderStruct += ([uint16] $this.Tagged) -shl 13
        $FrameHeaderStruct += ([uint16] $this.Addressable) -shl 12
        $FrameHeaderStruct += $this.Protocol -band 4095
        $BinaryWriter.Write($FrameHeaderStruct)

        $BinaryWriter.Write($this.Source)
        #EndRegion Frame Header

        #Region Frame Address
        $BinaryWriter.Write($this.Target)
        $BinaryWriter.Write($this.Reserved1)

        [byte] $FrameAddressStruct = 0
        $FrameAddressStruct += ($this.Reserved2 -band 63) -shl 2
        $FrameAddressStruct += ([byte] $this.AcknowledgementRequired) -shl 1
        $FrameAddressStruct += [byte] $this.ResponseRequired
        $BinaryWriter.Write($FrameAddressStruct)

        $BinaryWriter.Write($this.Sequence)
        #EndRegion Frame Address

        #Region Protocol Header
        $BinaryWriter.Write([uint64] (($this.Timestamp.ToUniversalTime() - [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)).Ticks * 100))
        $BinaryWriter.Write([uint16] $this.Type.value__)
        $BinaryWriter.Write($this.Reserved4)
        #EndRegion Protocol Header

        return $MemoryStream.ToArray()
    }

    [string] ToString() {
        return $this.ToString($false)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new()

        $StringBuilder.AppendFormat("Type: {0}", $this.Type)
        if ($AllFields) {$StringBuilder.AppendFormat(", Origin: {0}", $this.Origin)}
        $StringBuilder.AppendFormat(", Tagged: {0}", $this.Tagged)
        if ($AllFields) {$StringBuilder.AppendFormat(", Addressable: {0}", $this.Addressable)}
        if ($AllFields) {$StringBuilder.AppendFormat(", Protocol: {0:X4}", $this.Protocol)}
        $StringBuilder.AppendFormat(", Source: {0:X8}", $this.Source)
        $StringBuilder.AppendFormat(", Target: {0}", [System.BitConverter]::ToString([System.BitConverter]::GetBytes($this.Target)))
        if ($AllFields) {$StringBuilder.AppendFormat(", R1: {0}", [System.Text.Encoding]::ASCII.GetString($this.Reserved1))}
        if ($AllFields) {$StringBuilder.AppendFormat(", R2: {0:X2}", $this.Reserved2)}
        $StringBuilder.AppendFormat(", AckReqd: {0}", $this.AcknowledgementRequired)
        $StringBuilder.AppendFormat(", ResponseReqd: {0}", $this.ResponseRequired)
        $StringBuilder.AppendFormat(", Sequence: {0}", $this.Sequence)
        $StringBuilder.AppendFormat(", Timestamp: {0:o}", $this.Timestamp)
        if ($AllFields) {$StringBuilder.AppendFormat(", R4: {0:X4}", $this.Reserved4)}

        return $StringBuilder.ToString()
    }
}

class LifxMessageFactory {
    static [LifxMessage] CreateLifxMessage([byte[]] $PacketData) {
        $TypeValue = [System.BitConverter]::ToUInt16($PacketData[32..33], 0)

        try {
            $MessageType = [LifxMesssageType] $TypeValue
            $TypeName = "LifxMessage{0}" -f $MessageType
            Write-Verbose -Message ("[LifxMessageFactory] Found Message Type: {0}" -f $TypeName)
        } catch [System.Management.Automation.PSInvalidCastException] {
            $TypeName = "LifxMessage"
            Write-Verbose -Message ("[LifxMessageFactory] Defaulting To Message Type: {0}" -f $TypeName)
        }

        [LifxMessage] $Message = $null

        # (,$PacketData) is a bit hacky, to force New-Object to pass $PacketData as a single [byte[]] parameter
        $Message = New-Object -TypeName $TypeName -ArgumentList (, $PacketData)
        return $Message
    }
}

class LifxMessage {
    [LifxHeader] $Header
    hidden [byte[]] $PayloadBytes

    LifxMessage() {
        $this.Header = [LifxHeader]::new()
        $this.PayloadBytes = $null
    }

    LifxMessage([byte[]] $PacketData) {
        $MemoryStream = [System.IO.MemoryStream]::new($PacketData)
        $BinaryReader = [System.IO.BinaryReader]::new($MemoryStream)

        $this.Header = [LifxHeader]::new($BinaryReader.ReadBytes([LifxHeader]::HEADER_SIZE_BYTES))

        if ($this.Header.Size -ne $MemoryStream.Length) {
            Write-Warning -Message ("[LifxMessage] Warning: Received byte count ({0}) not equal to header size count ({1})" -f $MemoryStream.Length, $this.Header.Size)
        }

        if ($MemoryStream.Length -gt [LifxHeader]::HEADER_SIZE_BYTES) {
            $this.PayloadBytes = $BinaryReader.ReadBytes($MemoryStream.Length - [LifxHeader]::HEADER_SIZE_BYTES)
        } else {
            $this.PayloadBytes = $null
        }
    }

    [byte[]] GetPayloadBytes() {
        return $this.PayloadBytes
    }

    [byte[]] GetMessageBytes() {
        $Payload = $this.GetPayloadBytes()

        if ($Payload) {
            $this.Header.Size = [LifxHeader]::HEADER_SIZE_BYTES + $Payload.Length
        } else {
            $this.Header.Size = [LifxHeader]::HEADER_SIZE_BYTES
        }

        $MessageBytes = $this.Header.GetHeaderBytes()
        Write-Verbose -Message ("[LifxMessage] Header: {0}" -f (($MessageBytes | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))

        if ($Payload) {
            $MessageBytes += $Payload
            Write-Verbose -Message ("[LifxMessage] Payload: {0}" -f (($Payload | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))
        }

        return $MessageBytes
    }

    [string] ToString() {
        return $this.ToString($false)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        if ($this.PayloadBytes) {
            $StringBuilder.AppendFormat(", Payload: {0}", [System.BitConverter]::ToString($this.PayloadBytes))
        }

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetService : LifxMessage {
    LifxMessageGetService() : base() {
        $this.Header.Type = [LifxMesssageType]::GetService
        $this.Header.Tagged = $true
    }

    LifxMessageGetService([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageStateService : LifxMessage {
    [LifxServiceType] $Service
    [uint32] $Port

    LifxMessageStateService() : base() {
        $this.Header.Type = [LifxMesssageType]::StateService
    }

    LifxMessageStateService([byte[]] $PacketData) : base($PacketData) {
        $this.Service = $this.PayloadBytes[0]
        $this.Port = [System.BitConverter]::ToUInt32($this.PayloadBytes, 1)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Service: {0}", $this.Service)
        $StringBuilder.AppendFormat(", Port: {0}", $this.Port)

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetHostInfo : LifxMessage {
    LifxMessageGetHostInfo() : base() {
        $this.Header.Type = [LifxMesssageType]::GetHostInfo
    }

    LifxMessageGetHostInfo([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageStateHostInfo : LifxMessage {
    [single] $Signal
    [uint32] $Tx
    [uint32] $Rx
    hidden [int16] $Reserved

    LifxMessageStateHostInfo() : base() {
        $this.Header.Type = [LifxMesssageType]::StateHostInfo
    }

    LifxMessageStateHostInfo([byte[]] $PacketData) : base($PacketData) {
        $this.Signal = [System.BitConverter]::ToSingle($this.PayloadBytes, 0)
        $this.Tx = [System.BitConverter]::ToUInt32($this.PayloadBytes, 4)
        $this.Rx = [System.BitConverter]::ToUInt32($this.PayloadBytes, 8)
        $this.Reserved = [System.BitConverter]::ToInt16($this.PayloadBytes, 12)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Signal: {0}", $this.Signal)
        $StringBuilder.AppendFormat(", TxCount: {0}", $this.Tx)
        $StringBuilder.AppendFormat(", RxCount: {0}", $this.Rx)
        if ($AllFields) {$StringBuilder.AppendFormat(", Reserved: {0}", $this.Reserved)}

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetHostFirmware : LifxMessage {
    LifxMessageGetHostFirmware() : base() {
        $this.Header.Type = [LifxMesssageType]::GetHostFirmware
    }

    LifxMessageGetHostFirmware([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageStateHostFirmware : LifxMessage {
    [datetime] $Build
    hidden [uint64] $Reserved
    [uint32] $Version

    LifxMessageStateHostFirmware() : base() {
        $this.Header.Type = [LifxMesssageType]::StateHostFirmware
    }

    LifxMessageStateHostFirmware([byte[]] $PacketData) : base($PacketData) {
        $this.Build = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc).AddTicks([System.BitConverter]::ToUInt64($this.PayloadBytes, 0) / 100)
        $this.Reserved = [System.BitConverter]::ToUInt64($this.PayloadBytes, 8)
        $this.Version = [System.BitConverter]::ToUInt32($this.PayloadBytes, 16)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", BuildDate: {0:o}", $this.Build)
        $StringBuilder.AppendFormat(", Version: {0:X8}", $this.Version)
        if ($AllFields) {$StringBuilder.AppendFormat(", Reserved: {0:X16}", $this.Reserved)}

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetWifiInfo : LifxMessage {
    LifxMessageGetWifiInfo() : base() {
        $this.Header.Type = [LifxMesssageType]::GetWifiInfo
    }

    LifxMessageGetWifiInfo([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageStateWifiInfo : LifxMessage {
    [single] $Signal
    [uint32] $Tx
    [uint32] $Rx
    hidden [int16] $Reserved

    LifxMessageStateWifiInfo() : base() {
        $this.Header.Type = [LifxMesssageType]::StateWifiInfo
    }

    LifxMessageStateWifiInfo([byte[]] $PacketData) : base($PacketData) {
        $this.Signal = [System.BitConverter]::ToSingle($this.PayloadBytes, 0)
        $this.Tx = [System.BitConverter]::ToUInt32($this.PayloadBytes, 4)
        $this.Rx = [System.BitConverter]::ToUInt32($this.PayloadBytes, 8)
        $this.Reserved = [System.BitConverter]::ToInt16($this.PayloadBytes, 12)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Signal: {0}", $this.Signal)
        $StringBuilder.AppendFormat(", TxCount: {0}", $this.Tx)
        $StringBuilder.AppendFormat(", RxCount: {0}", $this.Rx)
        if ($AllFields) {$StringBuilder.AppendFormat(", Reserved: {0}", $this.Reserved)}

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetWifiFirmware : LifxMessage {
    LifxMessageGetWifiFirmware() : base() {
        $this.Header.Type = [LifxMesssageType]::GetWifiFirmware
    }

    LifxMessageGetWifiFirmware([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageStateWifiFirmware : LifxMessage {
    [datetime] $Build
    hidden [uint64] $Reserved
    [uint32] $Version

    LifxMessageStateWifiFirmware() : base() {
        $this.Header.Type = [LifxMesssageType]::StateWifiFirmware
    }

    LifxMessageStateWifiFirmware([byte[]] $PacketData) : base($PacketData) {
        $this.Build = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc).AddTicks([System.BitConverter]::ToUInt64($this.PayloadBytes, 0) / 100)
        $this.Reserved = [System.BitConverter]::ToUInt64($this.PayloadBytes, 8)
        $this.Version = [System.BitConverter]::ToUInt32($this.PayloadBytes, 16)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", BuildDate: {0:o}", $this.Build)
        $StringBuilder.AppendFormat(", Version: {0:X8}", $this.Version)
        if ($AllFields) {$StringBuilder.AppendFormat(", Reserved: {0:X16}", $this.Reserved)}

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetPower : LifxMessage {
    LifxMessageGetPower() : base() {
        $this.Header.Type = [LifxMesssageType]::GetPower
    }

    LifxMessageGetPower([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageSetPower : LifxMessage {
    [LifxPowerLevel] $PowerLevel

    LifxMessageSetPower() : base() {
        $this.Header.Type = [LifxMesssageType]::SetPower
        $this.PowerLevel = [LifxPowerLevel]::Enabled
    }

    LifxMessageSetPower([LifxPowerLevel] $PowerLevel) : base() {
        $this.Header.Type = [LifxMesssageType]::SetPower
        $this.PowerLevel = $PowerLevel
    }

    LifxMessageSetPower([byte[]] $PacketData) : base($PacketData) {
    }

    [byte[]] GetPayloadBytes() {
        $this.PayloadBytes = @([System.BitConverter]::GetBytes([uint16] $this.PowerLevel))
        return $this.PayloadBytes
    }
}

class LifxMessageStatePower : LifxMessage {
    [LifxPowerLevel] $PowerLevel

    LifxMessageStatePower() : base() {
        $this.Header.Type = [LifxMesssageType]::StatePower
    }

    LifxMessageStatePower([byte[]] $PacketData) : base($PacketData) {
        $this.PowerLevel = [LifxPowerLevel] [System.BitConverter]::ToUInt16($this.PayloadBytes, 0)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", PowerLevel: {0}", $this.PowerLevel)

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetLabel : LifxMessage {
    LifxMessageGetLabel() : base() {
        $this.Header.Type = [LifxMesssageType]::GetLabel
    }

    LifxMessageGetLabel([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageSetLabel : LifxMessage {
    [string] $Label

    LifxMessageSetLabel() : base() {
        $this.Header.Type = [LifxMesssageType]::SetLabel
    }

    LifxMessageSetLabel([string] $Label) : base() {
        $this.Header.Type = [LifxMesssageType]::SetLabel
        $this.Label = $Label
    }

    LifxMessageSetLabel([byte[]] $PacketData) : base($PacketData) {
    }

    [byte[]] GetPayloadBytes() {
        if ($this.Label) {
            $LabelBytes = @([System.Text.Encoding]::UTF8.GetBytes($this.Label))

            if ($LabelBytes.Length -lt 32) {
                $LabelBytes += [byte[]]::new(32 - $LabelBytes.Length)
}

            $this.PayloadBytes = $LabelBytes[0..31]
        }

        return $this.PayloadBytes
    }
}

class LifxMessageStateLabel : LifxMessage {
    [string] $Label

    LifxMessageStateLabel() : base() {
        $this.Header.Type = [LifxMesssageType]::StateLabel
    }

    LifxMessageStateLabel([byte[]] $PacketData) : base($PacketData) {
        $this.Label = [System.Text.Encoding]::UTF8.GetString($this.PayloadBytes[0..31])
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Label: {0}", $this.Label)

        return $StringBuilder.ToString()
}
}

class LifxMessageGetVersion : LifxMessage {
    LifxMessageGetVersion() : base() {
        $this.Header.Type = [LifxMesssageType]::GetVersion
    }

    LifxMessageGetVersion([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageStateVersion : LifxMessage {
    [uint32] $Vendor
    [uint32] $Product
    [uint32] $Version

    LifxMessageStateVersion() : base() {
        $this.Header.Type = [LifxMesssageType]::StateVersion
    }

    LifxMessageStateVersion([byte[]] $PacketData) : base($PacketData) {
        $this.Vendor = [System.BitConverter]::ToUInt32($this.PayloadBytes, 0)
        $this.Product = [System.BitConverter]::ToUInt32($this.PayloadBytes, 4)
        $this.Version = [System.BitConverter]::ToUInt32($this.PayloadBytes, 8)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Vendor: {0}", $this.Vendor)
        $StringBuilder.AppendFormat(", Product: {0}", $this.Product)
        $StringBuilder.AppendFormat(", Version: {0}", $this.Version)

        return $StringBuilder.ToString()
    }
}

class LifxMessageGetInfo : LifxMessage {
    LifxMessageGetInfo() : base() {
        $this.Header.Type = [LifxMesssageType]::GetInfo
    }

    LifxMessageGetInfo([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageStateInfo : LifxMessage {
    [datetime] $Time
    [timespan] $Uptime
    [timespan] $Downtime

    LifxMessageStateInfo() : base() {
        $this.Header.Type = [LifxMesssageType]::StateInfo
    }

    LifxMessageStateInfo([byte[]] $PacketData) : base($PacketData) {
        $this.Time = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc).AddTicks([System.BitConverter]::ToUInt64($this.PayloadBytes, 0) / 100).ToLocalTime()
        $this.Uptime = [timespan]::new([System.BitConverter]::ToUInt64($this.PayloadBytes, 8) / 100)
        $this.Downtime = [timespan]::new([System.BitConverter]::ToUInt64($this.PayloadBytes, 16) / 100)
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Time: {0:o}", $this.Time)
        $StringBuilder.AppendFormat(", Uptime: {0}", $this.Uptime)
        $StringBuilder.AppendFormat(", Downtime: {0}", $this.Downtime)

        return $StringBuilder.ToString()
    }
}

class LifxMessageAcknowledgement : LifxMessage {
    LifxMessageAcknowledgement() : base() {
        $this.Header.Type = [LifxMesssageType]::Acknowledgement
    }

    LifxMessageAcknowledgement([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageGetLocation : LifxMessage {
    LifxMessageGetLocation() : base() {
        $this.Header.Type = [LifxMesssageType]::GetLocation
    }

    LifxMessageGetLocation([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageSetLocation : LifxMessage {
    [guid] $Location
    [string] $Label
    [datetime] $UpdatedAt

    LifxMessageSetLocation() : base() {
        $this.Header.Type = [LifxMesssageType]::SetLocation
    }

    LifxMessageSetLocation([guid] $Location, [string] $Label, [datetime] $UpdatedAt = [datetime]::UtcNow) : base() {
        $this.Header.Type = [LifxMesssageType]::SetLocation
        $this.Location = $Location
        $this.Label = $Label
        $this.UpdatedAt = $UpdatedAt
    }

    LifxMessageSetLocation([byte[]] $PacketData) : base($PacketData) {
    }

    [byte[]] GetPayloadBytes() {
        $this.PayloadBytes = $this.Location.ToByteArray()

        $LabelBytes = @([System.Text.Encoding]::UTF8.GetBytes($this.Label))

        if ($LabelBytes.Length -lt 32) {
            $LabelBytes += [byte[]]::new(32 - $LabelBytes.Length)
        }

        $this.PayloadBytes += $LabelBytes[0..31]

        $this.PayloadBytes += [System.BitConverter]::GetBytes([uint64] (($this.UpdatedAt.ToUniversalTime() - [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)).Ticks * 100))

        return $this.PayloadBytes
    }
}

class LifxMessageStateLocation : LifxMessage {
    [guid] $Location
    [string] $Label
    [datetime] $UpdatedAt

    LifxMessageStateLocation() : base() {
        $this.Header.Type = [LifxMesssageType]::StateLocation
    }

    LifxMessageStateLocation([byte[]] $PacketData) : base($PacketData) {
        $this.Location = [guid]::new([byte[]] $this.PayloadBytes[0..15])
        $this.Label = [System.Text.Encoding]::UTF8.GetString($this.PayloadBytes[16..47])
        $this.UpdatedAt = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc).AddTicks([System.BitConverter]::ToUInt64($this.PayloadBytes, 48) / 100).ToLocalTime()
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Location: {0}", $this.Location)
        $StringBuilder.AppendFormat(", Label: {0}", $this.Label)
        $StringBuilder.AppendFormat(", UpdatedAt: {0:o}", $this.UpdatedAt)

        return $StringBuilder.ToString()
}
}

class LifxMessageGetGroup : LifxMessage {
    LifxMessageGetGroup() : base() {
        $this.Header.Type = [LifxMesssageType]::GetGroup
    }

    LifxMessageGetGroup([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageSetGroup : LifxMessage {
    [guid] $Group
    [string] $Label
    [datetime] $UpdatedAt

    LifxMessageSetGroup() : base() {
        $this.Header.Type = [LifxMesssageType]::SetGroup
    }

    LifxMessageSetGroup([guid] $Group, [string] $Label, [datetime] $UpdatedAt = [datetime]::UtcNow) : base() {
        $this.Header.Type = [LifxMesssageType]::SetGroup
        $this.Group = $Group
        $this.Label = $Label
        $this.UpdatedAt = $UpdatedAt
    }

    LifxMessageSetGroup([byte[]] $PacketData) : base($PacketData) {
    }

    [byte[]] GetPayloadBytes() {
        $this.PayloadBytes = $this.Group.ToByteArray()

        $LabelBytes = @([System.Text.Encoding]::UTF8.GetBytes($this.Label))

        if ($LabelBytes.Length -lt 32) {
            $LabelBytes += [byte[]]::new(32 - $LabelBytes.Length)
        }

        $this.PayloadBytes += $LabelBytes[0..31]

        $this.PayloadBytes += [System.BitConverter]::GetBytes([uint64] (($this.UpdatedAt.ToUniversalTime() - [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)).Ticks * 100))

        return $this.PayloadBytes
    }
}

class LifxMessageStateGroup : LifxMessage {
    [guid] $Group
    [string] $Label
    [datetime] $UpdatedAt

    LifxMessageStateGroup() : base() {
        $this.Header.Type = [LifxMesssageType]::StateGroup
    }

    LifxMessageStateGroup([byte[]] $PacketData) : base($PacketData) {
        $this.Group = [guid]::new([byte[]] $this.PayloadBytes[0..15])
        $this.Label = [System.Text.Encoding]::UTF8.GetString($this.PayloadBytes[16..47])
        $this.UpdatedAt = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc).AddTicks([System.BitConverter]::ToUInt64($this.PayloadBytes, 48) / 100).ToLocalTime()
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Group: {0}", $this.Group)
        $StringBuilder.AppendFormat(", Label: {0}", $this.Label)
        $StringBuilder.AppendFormat(", UpdatedAt: {0:o}", $this.UpdatedAt)

        return $StringBuilder.ToString()
    }
}

class LifxMessageEchoRequest : LifxMessage {
    [string] $EchoMessage

    LifxMessageEchoRequest() : base() {
        $this.Header.Type = [LifxMesssageType]::EchoRequest
    }

    LifxMessageEchoRequest([string] $EchoMessage) : base() {
        $this.Header.Type = [LifxMesssageType]::EchoRequest
        $this.EchoMessage = $EchoMessage
    }

    LifxMessageEchoRequest([byte[]] $PacketData) : base($PacketData) {
    }

    [byte[]] GetPayloadBytes() {
        $EchoMessageBytes = @([System.Text.Encoding]::UTF8.GetBytes($this.EchoMessage))

        if ($EchoMessageBytes.Length -lt 64) {
            $EchoMessageBytes += [byte[]]::new(64 - $EchoMessageBytes.Length)
        }

        $this.PayloadBytes = $EchoMessageBytes[0..63]

        return $this.PayloadBytes
    }
}

class LifxMessageEchoResponse : LifxMessage {
    [string] $EchoMessage

    LifxMessageEchoResponse() : base() {
        $this.Header.Type = [LifxMesssageType]::EchoResponse
    }

    LifxMessageEchoResponse([byte[]] $PacketData) : base($PacketData) {
        $this.EchoMessage = [System.Text.Encoding]::UTF8.GetString($this.PayloadBytes[0..63])
    }

    [string] ToString([bool] $AllFields) {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString($AllFields))
        $StringBuilder.AppendFormat(", Payload: {0}", $this.EchoMessage)

        return $StringBuilder.ToString()
    }
}

class LifxMessageLightGet : LifxMessage {
    LifxMessageLightGet() : base() {
        $this.Header.Type = [LifxMesssageType]::LightGet
    }

    LifxMessageLightGet([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightSetColor : LifxMessage {
    LifxMessageLightSetColor() : base() {
        $this.Header.Type = [LifxMesssageType]::GetSerLightSetColorvice
    }

    LifxMessageLightSetColor([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightSetWaveform : LifxMessage {
    LifxMessageLightSetWaveform() : base() {
        $this.Header.Type = [LifxMesssageType]::LightSetWaveform
    }

    LifxMessageLightSetWaveform([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightState : LifxMessage {
    LifxMessageLightState() : base() {
        $this.Header.Type = [LifxMesssageType]::LightState
    }

    LifxMessageLightState([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightGetPower : LifxMessage {
    LifxMessageLightGetPower() : base() {
        $this.Header.Type = [LifxMesssageType]::LightGetPower
    }

    LifxMessageLightGetPower([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightSetPower : LifxMessage {
    LifxMessageLightSetPower() : base() {
        $this.Header.Type = [LifxMesssageType]::LightSetPower
    }

    LifxMessageLightSetPower([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightStatePower : LifxMessage {
    LifxMessageLightStatePower() : base() {
        $this.Header.Type = [LifxMesssageType]::LightStatePower
    }

    LifxMessageLightStatePower([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightSetWaveformOptional : LifxMessage {
    LifxMessageLightSetWaveformOptional() : base() {
        $this.Header.Type = [LifxMesssageType]::LightSetWaveformOptional
    }

    LifxMessageLightSetWaveformOptional([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightGetInfrared : LifxMessage {
    LifxMessageLightGetInfrared() : base() {
        $this.Header.Type = [LifxMesssageType]::LightGetInfrared
    }

    LifxMessageLightGetInfrared([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightStateInfrared : LifxMessage {
    LifxMessageLightStateInfrared() : base() {
        $this.Header.Type = [LifxMesssageType]::LightStateInfrared
    }

    LifxMessageLightStateInfrared([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageLightSetInfrared : LifxMessage {
    LifxMessageLightSetInfrared() : base() {
        $this.Header.Type = [LifxMesssageType]::LightSetInfrared
    }

    LifxMessageLightSetInfrared([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageMultiZoneSetColorZones : LifxMessage {
    LifxMessageMultiZoneSetColorZones() : base() {
        $this.Header.Type = [LifxMesssageType]::MultiZoneSetColorZones
    }

    LifxMessageMultiZoneSetColorZones([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageMultiZoneGetColorZones : LifxMessage {
    LifxMessageMultiZoneGetColorZones() : base() {
        $this.Header.Type = [LifxMesssageType]::MultiZoneGetColorZones
    }

    LifxMessageMultiZoneGetColorZones([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageMultiZoneStateZone : LifxMessage {
    LifxMessageMultiZoneStateZone() : base() {
        $this.Header.Type = [LifxMesssageType]::MultiZoneStateZone
    }

    LifxMessageMultiZoneStateZone([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageMultiZoneStateMultiZone : LifxMessage {
    LifxMessageMultiZoneStateMultiZone() : base() {
        $this.Header.Type = [LifxMesssageType]::MultiZoneStateMultiZone
    }

    LifxMessageMultiZoneStateMultiZone([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageTileGetDeviceChain : LifxMessage {
    LifxMessageTileGetDeviceChain() : base() {
        $this.Header.Type = [LifxMesssageType]::TileGetDeviceChain
    }

    LifxMessageTileGetDeviceChain([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageTileStateDeviceChain : LifxMessage {
    LifxMessageTileStateDeviceChain() : base() {
        $this.Header.Type = [LifxMesssageType]::TileStateDeviceChain
    }

    LifxMessageTileStateDeviceChain([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageTileSetUserPosition : LifxMessage {
    LifxMessageTileSetUserPosition() : base() {
        $this.Header.Type = [LifxMesssageType]::TileSetUserPosition
    }

    LifxMessageTileSetUserPosition([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageTileGetTileState64 : LifxMessage {
    LifxMessageTileGetTileState64() : base() {
        $this.Header.Type = [LifxMesssageType]::TileGetTileState64
    }

    LifxMessageTileGetTileState64([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageTileStateTileState64 : LifxMessage {
    LifxMessageTileStateTileState64() : base() {
        $this.Header.Type = [LifxMesssageType]::TileStateTileState64
    }

    LifxMessageTileStateTileState64([byte[]] $PacketData) : base($PacketData) {
    }
}

class LifxMessageTileSetTileState64 : LifxMessage {
    LifxMessageTileSetTileState64() : base() {
        $this.Header.Type = [LifxMesssageType]::TileSetTileState64
    }

    LifxMessageTileSetTileState64([byte[]] $PacketData) : base($PacketData) {
    }
}
