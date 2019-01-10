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
        $DeviceType
    )

    Begin {
        [uint16] $LIFX_BROADCAST_PORT = 56700
        $ReceiveTimeout = New-TimeSpan -Seconds 5
    }

    Process {
        if ($All) {
            $LocalIP = [System.Net.IPAddress]::Any
            $LocalPort = 0 # $LIFX_BROADCAST_PORT # v1 devices may require localport to be the LIFX default port 57600

            $LocalEndpoint = [System.Net.IPEndPoint]::new($LocalIP, $LocalPort)
            Write-Verbose -Message ("Local Endpoint: {0}:{1}" -f $LocalEndpoint.Address.ToString(),$LocalEndpoint.Port.ToString())

            $UdpClient = [System.Net.Sockets.UdpClient]::new($LocalEndpoint)
            $UdpClient.DontFragment = $true
            $UdpClient.EnableBroadcast = $true

            # Blocking Receive() calls, until we do threading/async/events or something
            $UdpClient.Client.Blocking = $true
            $UdpClient.Client.ReceiveTimeout = $ReceiveTimeout.TotalMilliseconds
            $UdpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)

            $RemoteEndpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Broadcast, $LIFX_BROADCAST_PORT)

            $Message = [LifxMessageGetService]::new()
            $MessageBytes = $Message.GetMessageBytes()
            $SendResult = $UdpClient.Send($MessageBytes, $MessageBytes.Length, $RemoteEndpoint)
            Write-Verbose -Message ("Sent {0} Bytes" -f $SendResult)

            $StartTime = [System.DateTime]::UtcNow

            $DiscoveredDevices = @{}

            while (([System.DateTime]::UtcNow - $StartTime) -le $ReceiveTimeout) {
                try {
                    $RemoteEndpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, $LIFX_BROADCAST_PORT)
                    $Content = $UdpClient.Receive([ref] $RemoteEndpoint)

                    Write-Verbose -Message ("Received {0} Bytes from {1}:{2}" -f $Content.Length, $RemoteEndpoint.Address.ToString(), $RemoteEndpoint.Port.ToString())
                    Write-Verbose -Message ("Received: {0}" -f (($Content | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))

                    $ReceivedMessage = [LifxMessageFactory]::CreateLifxMessage($Content)
                    Write-Verbose -Message ("Message: {0}" -f $ReceivedMessage.ToString())

                    if ($ReceivedMessage -is [LifxMessageStateService]) {
                        $RemoteEndpoint.Port = $ReceivedMessage.Port
                        $Device = [LifxLanDevice] @{Identifier = $ReceivedMessage.Header.Target; IPEndPoint = $RemoteEndpoint; ServiceTypes = $ReceivedMessage.Service}

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
                        $SendResult = $UdpClient.Send($MessageBytes, $MessageBytes.Length, $RemoteEndpoint)
                        Write-Verbose -Message ("Sent {0} Bytes" -f $SendResult)

                        $Content = $UdpClient.Receive([ref] $RemoteEndpoint)

                        Write-Verbose -Message ("Received {0} Bytes from {1}:{2}" -f $Content.Length, $RemoteEndpoint.Address.ToString(), $RemoteEndpoint.Port.ToString())
                        Write-Verbose -Message ("Received: {0}" -f (($Content | ForEach-Object -Process {$PSItem.ToString("X2")}) -join ","))

                        $ReceivedMessage = [LifxMessageFactory]::CreateLifxMessage($Content)
                        Write-Verbose -Message ("Message: {0}" -f $ReceivedMessage.ToString())

                        switch ($ReceivedMessage.GetType()) {
                            ([LifxMessageStateService]) {
                                $RemoteEndpoint.Port = $ReceivedMessage.Port
                                $Device = [LifxLanDevice] @{Identifier = $ReceivedMessage.Header.Target; IPEndPoint = $RemoteEndpoint; ServiceTypes = $ReceivedMessage.Service}

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
                            Default {}
                        }
                        if ($ReceivedMessage -is [LifxMessageStateService]) {
                        }
                    } catch [System.Net.Sockets.SocketException] {
                        Write-Verbose -Message "Timed Out"
                    }
                }
            }

            if ($UdpClient) {
                $UdpClient.Close()
            }

            return $DiscoveredDevices.Values
        }
    }

    End {
    }
}
