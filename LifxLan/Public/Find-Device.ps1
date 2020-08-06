#Requires -Version 5.1

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>

function Find-Device {
    [CmdletBinding(
        DefaultParameterSetName = 'Discovery',
        PositionalBinding = $false,
        ConfirmImpact = 'Medium'
    )]

    [OutputType([LifxLanDevice[]])]

    Param (
        # Perform network broadcast device discovery
        [Parameter(ParameterSetName = 'Discovery', Mandatory = $true)]
        [switch]
        $All,

        # Specific device IP address
        [Parameter(ParameterSetName = 'Manual Device', Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        # Specific device MAC address
        [Parameter(ParameterSetName = 'Manual Device')]
        [System.Net.NetworkInformation.PhysicalAddress]
        $MACAddress,

        # Select only devices of a specific type
        [LifxDeviceType]
        $DeviceType,

        [timespan]
        $ReceiveTimeout = (New-TimeSpan -Seconds 5),

        # Local IP address to use as source
        [System.Net.IPAddress]
        $LocalIP = [System.Net.IPAddress]::IPv6Any,

        # v1 devices may require localport to be the LIFX default port 57600
        [ValidateSet(0, 57600)]
        [uint16]
        $LocalPort = 57600
    )

    Begin {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

        [uint16] $LIFX_BROADCAST_PORT = 56700
    }

    Process {
        if ($All) {
            $LocalEndpoint = [System.Net.IPEndPoint]::new($LocalIP, $LocalPort)
            Write-Verbose -Message ("Local Endpoint: {0}:{1}" -f $LocalEndpoint.Address.ToString(), $LocalEndpoint.Port.ToString())

            $UDPSocket = [System.Net.Sockets.Socket]::new(
                [System.Net.Sockets.AddressFamily]::InterNetworkV6,
                [System.Net.Sockets.SocketType]::Dgram,
                [System.Net.Sockets.ProtocolType]::Udp
            )
            $UDPSocket.DualMode = $true
            $UDPSocket.EnableBroadcast = $true

            <#
            # SetIPProtectionLevel may not be supported on non-Windows
            $UDPSocket.SetIPProtectionLevel(
                [System.Net.Sockets.IPProtectionLevel]::Restricted
            )
            #>

            $UDPSocket.SetSocketOption(
                [System.Net.Sockets.SocketOptionLevel]::Socket,
                [System.Net.Sockets.SocketOptionName]::ReuseAddress,
                $true
            )

            $UDPSocket.SetSocketOption(
                [System.Net.Sockets.SocketOptionLevel]::IP,
                [System.Net.Sockets.SocketOptionName]::PacketInformation,
                $true
            )

            $UDPSocket.SetSocketOption(
                [System.Net.Sockets.SocketOptionLevel]::IPv6,
                [System.Net.Sockets.SocketOptionName]::PacketInformation,
                $true
            )

            $UDPSocket.Bind([System.Net.EndPoint] $LocalEndpoint)

            # Blocking ReceiveFrom() calls, until we do threading/async/events or something
            $UDPSocket.Blocking = $true
            $UDPSocket.ReceiveTimeout = $ReceiveTimeout.TotalMilliseconds

            $BroadcastEndpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Broadcast, $LIFX_BROADCAST_PORT)

            $Message = [LifxMessageGetService]::new()
            $MessageBytes = $Message.GetMessageBytes()

            $SendResult = $UDPSocket.SendTo($MessageBytes, $BroadcastEndpoint)
            Write-Verbose -Message ("Sent {0} Bytes" -f $SendResult)

            $StartTime = [System.DateTime]::UtcNow

            $DiscoveredDevices = @{}

            while (([System.DateTime]::UtcNow - $StartTime) -le $ReceiveTimeout) {
                try {
                    $ReceiveBuffer = [byte[]]::new($UDPSocket.ReceiveBufferSize)
                    $ReceiveEndpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::IPv6Any, $LIFX_BROADCAST_PORT)
                    $ReceivePacketInformation = New-Object -TypeName System.Net.Sockets.IPPacketInformation

                    $ReceiveSocketFlags = [System.Net.Sockets.SocketFlags]::None
                    $ReceiveResult = $UDPSocket.ReceiveMessageFrom($ReceiveBuffer, 0, $ReceiveBuffer.Length, [ref] $ReceiveSocketFlags, [ref] $ReceiveEndpoint, [ref] $ReceivePacketInformation)
                    $Content = $ReceiveBuffer[0..($ReceiveResult - 1)]

                    Write-Verbose -Message ("Received {0} Bytes from {1}:{2} on interface {3} address {4} with flags {5}" -f $ReceiveResult, $ReceiveEndpoint.Address.ToString(), $ReceiveEndpoint.Port.ToString(), $ReceivePacketInformation.Interface, $ReceivePacketInformation.Address, $ReceiveSocketFlags.ToString())
                    #Write-Verbose -Message ("Received: {0}" -f (($Content | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))

                    $ReceivedMessage = [LifxMessageFactory]::CreateLifxMessage($Content)
                    Write-Verbose -Message ("Message: {0}" -f $ReceivedMessage.ToString())

                    if ($ReceivedMessage -is [LifxMessageStateService]) {
                        $ReceiveEndpoint.Port = $ReceivedMessage.Port
                        $Device = [LifxLanDevice] @{Identifier = $ReceivedMessage.Header.Target; IPEndPoint = $ReceiveEndpoint; ServiceTypes = $ReceivedMessage.Service }

                        if ($DiscoveredDevices.ContainsKey($Device.Identifier) -and $DiscoveredDevices[$Device.Identifier].ServiceTypes -notcontains $Device.ServiceTypes) {
                            $DiscoveredDevices[$Device.Identifier].ServiceTypes += $Device.ServiceTypes
                        } else {
                            $DiscoveredDevices.Add($Device.Identifier, $Device)
                        }
                    }
                } catch [System.Net.Sockets.SocketException] {
                    Write-Verbose -Message "Timed Out"
                }
            }

            $MessageTypes = @(
                [LifxMessageGetLabel]
                [LifxMessageGetLocation]
                [LifxMessageGetGroup]
                [LifxMessageGetVersion]
            )

            foreach ($Device in $DiscoveredDevices.Values) {
                foreach ($MessageType in $MessageTypes) {
                    try {
                        $RemoteEndpoint = $Device.IPEndPoint

                        $Message = $MessageType::new()
                        $MessageBytes = $Message.GetMessageBytes()
                        $SendResult = $UDPSocket.SendTo($MessageBytes, $RemoteEndpoint)
                        Write-Verbose -Message ("Sent {0} Bytes" -f $SendResult)

                        $ReceiveBuffer = [byte[]]::new($UDPSocket.ReceiveBufferSize)
                        $ReceivePacketInformation = New-Object -TypeName System.Net.Sockets.IPPacketInformation

                        $ReceiveSocketFlags = [System.Net.Sockets.SocketFlags]::None
                        $ReceiveResult = $UDPSocket.ReceiveMessageFrom($ReceiveBuffer, 0, $ReceiveBuffer.Length, [ref] $ReceiveSocketFlags, [ref] $RemoteEndpoint, [ref] $ReceivePacketInformation)
                        $Content = $ReceiveBuffer[0..($ReceiveResult - 1)]

                        Write-Verbose -Message ("Received {0} Bytes from {1}:{2} on interface {3} address {4} with flags {5}" -f $ReceiveResult, $RemoteEndpoint.Address.ToString(), $RemoteEndpoint.Port.ToString(), $ReceivePacketInformation.Interface, $ReceivePacketInformation.Address, $ReceiveSocketFlags.ToString())
                        #Write-Verbose -Message ("Received: {0}" -f (($Content | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))

                        $ReceivedMessage = [LifxMessageFactory]::CreateLifxMessage($Content)
                        Write-Verbose -Message ("Message: {0}" -f $ReceivedMessage.ToString())

                        switch ($ReceivedMessage.GetType()) {
                            ([LifxMessageStateService]) {
                                $RemoteEndpoint.Port = $ReceivedMessage.Port
                                $Device = [LifxLanDevice] @{Identifier = $ReceivedMessage.Header.Target; IPEndPoint = $RemoteEndpoint; ServiceTypes = $ReceivedMessage.Service }

                                if ($DiscoveredDevices.ContainsKey($Device.Identifier) -and $DiscoveredDevices[$Device.Identifier].ServiceTypes -notcontains $Device.ServiceTypes) {
                                    $DiscoveredDevices[$Device.Identifier].ServiceTypes += $Device.ServiceTypes
                                } else {
                                    $DiscoveredDevices.Add($Device.Identifier, $Device)
                                }
                            }
                            ([LifxMessageStateLabel]) {
                                $Device.Label = $ReceivedMessage.Label
                            }
                            ([LifxMessageStateLocation]) {
                                $Device.Location = $ReceivedMessage.Label
                            }
                            ([LifxMessageStateGroup]) {
                                $Device.Group = $ReceivedMessage.Label
                            }
                            ([LifxMessageStateVersion]) {
                                $Device.Hardware = New-Object -TypeName LifxLanDeviceVersion
                                $Device.Hardware.Vendor = $ReceivedMessage.Vendor
                                $Device.Hardware.Product = $ReceivedMessage.Product
                                $Device.Hardware.Version = $ReceivedMessage.Version
                            }
                            Default {
                            }
                        }
                        if ($ReceivedMessage -is [LifxMessageStateService]) {
                        }
                    } catch [System.Net.Sockets.SocketException] {
                        Write-Verbose -Message "Timed Out"
                    }
                }
            }

            if ($UDPSocket) {
                $UDPSocket.Close()
                $UDPSocket.Dispose()
                $UDPSocket = $null
            }

            return $DiscoveredDevices.Values
        }
    }

    End {
    }
}
