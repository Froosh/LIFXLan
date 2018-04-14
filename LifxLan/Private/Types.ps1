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
    [System.DateTime] $Timestamp = [System.DateTime]::Now       # 64 bits [24..31] [uint64] # Nanoseconds since unix epoch (utc)
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
        $this.Timestamp = [System.DateTime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc).AddTicks($BinaryReader.ReadUInt64() / 100).ToLocalTime()
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
        $BinaryWriter.Write([uint64] (($this.Timestamp.ToUniversalTime() - [System.DateTime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)).Ticks * 100))
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
        $StringBuilder.AppendFormat(", Timestamp: {0}", $this.Timestamp)
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
        if ($this.Header.Size -gt $MemoryStream.Length) {
            $this.PayloadBytes = $BinaryReader.ReadBytes($MemoryStream.Length - [LifxHeader]::HEADER_SIZE_BYTES)
        } else {
            $this.PayloadBytes = $null
        }
    }

    [byte[]] GetMessageBytes() {
        if ($this.PayloadBytes) {
            $this.Header.Size += $this.PayloadBytes.Length
        }

        $MessageBytes = $this.Header.GetHeaderBytes()
        Write-Verbose -Message ("Header: {0}" -f (($MessageBytes | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))

        if ($this.PayloadBytes) {
            $MessageBytes += $this.PayloadBytes
            Write-Verbose -Message ("Payload: {0}" -f (($this.PayloadBytes | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))
        }

        return $MessageBytes
    }

    [string] ToString() {
        $StringBuilder = [System.Text.StringBuilder]::new($this.Header.ToString())
        if ($this.PayloadBytes) {
            $StringBuilder.AppendLine($this.PayloadBytes.ToString("X2"))
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
    LifxMessageStateService() : base() {
        $this.Header.Type = [LifxMesssageType]::StateService
        $this.Header.Tagged = $true
    }

    LifxMessageStateService([byte[]] $PacketData) : base($PacketData) {
    }
}