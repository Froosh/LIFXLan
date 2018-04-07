@{
    Description            = "Control LIFX Lights with the LIFX LAN v2 protocol"
    GUID                   = "5dbbc6b0-9b21-408e-98a4-6ce9bf22925d"

    # Follow Semantic Versioning https://semver.org/
    ModuleVersion          = "0.0.1"

    Author                 = "Robin@froosh.net"
    CompanyName            = "Froosh Networks"
    Copyright              = "(c) 2018 Robin Frousheger"

    ProcessorArchitecture  = "None"
    CompatiblePSEditions   = @("Desktop", "Core")
    PowerShellVersion      = "5.1"

    # PowerShellHostName     = ""
    # PowerShellHostVersion  = ""

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ""
    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion             = ""

    DefaultCommandPrefix   = "LifxLan"

    RootModule             = "LifxLan.psm1"
    NestedModules          = @()

    RequiredModules        = @()
    RequiredAssemblies     = @()

    AliasesToExport        = @()
    DscResourcesToExport   = @()
    CmdletsToExport        = @()
    FunctionsToExport      = @("Find-Device")
    VariablesToExport      = @()

    FormatsToProcess       = @()
    ScriptsToProcess       = @("Public\Types.ps1")
    TypesToProcess         = @()

    ModuleList             = @()
    FileList               = @()

    # PowerShell Gallery: Define your module"s metadata
    PrivateData = @{
        PSData = @{
            # What keywords represent your PowerShell module? (eg. cloud, tools, framework, vendor)
            Tags         = @("LIFX")

            # What software license is your code being released under? (see https://opensource.org/licenses)
            LicenseUri   = "https://opensource.org/licenses/MIT"

            # What is the URL to your project"s website?
            ProjectUri   = ""

            # What is the URI to a custom icon file for your project? (optional)
            IconUri      = ""

            # What new features, bug fixes, or deprecated features, are part of this release?
            ReleaseNotes = ""
        }
    }

    # If your module supports updateable help, what is the URI to the help archive? (optional)
    # HelpInfoURI = ""
}
