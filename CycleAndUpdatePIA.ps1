# CycleAndUpdatePIA.ps1

# ==================== Configuration ====================

# Paths to executables
$piactlPath = "C:\Program Files\Private Internet Access\piactl.exe"  # Ensure this path is correct
$vboxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"  # Ensure this path is correct

# VirtualBox VM Name
$vmName = "kali-linux-2024.2-virtualbox-amd64"  # Replace with your actual VirtualBox VM name

# Selection Mode: "Sequential" or "Random"
$selectionMode = "Random"  # Change to "Random" if preferred

# List of region identifiers to cycle through (Ensure these match PIA's region names)
$regionList = @(
    "south-africa",
    "liechtenstein",
    "morocco",
    "it-milano",
    "it-streaming-optimized",
    "belgium",
    "luxembourg",
    "andorra",
    "bosnia-and-herzegovina",
    "uk-streaming-optimized",
    "uk-london",
    "uk-manchester",
    "uk-southampton",
    "es-madrid",
    "es-valencia",
    "algeria",
    "portugal",
    "nl-netherlands-streaming-optimized",
    "netherlands",
    "serbia",
    "slovakia",
    "austria",
    "dk-streaming-optimized",
    "dk-copenhagen",
    "czech-republic",
    "albania",
    "de-germany-streaming-optimized",
    "de-frankfurt",
    "de-berlin",
    "slovenia",
    "france",
    "monaco",
    "ireland",
    "montenegro",
    "poland",
    "norway",
    "se-streaming-optimized",
    "se-stockholm",
    "croatia",
    "egypt",
    "nigeria",
    "georgia",
    "kazakhstan",
    "armenia",
    "moldova",
    "ukraine",
    "switzerland",
    "isle-of-man",
    "cyprus",
    "fi-helsinki",
    "fi-streaming-optimized",
    "estonia",
    "latvia",
    "israel",
    "bulgaria",
    "north-macedonia",
    "greece",
    "lithuania",
    "turkey",
    "bahamas",
    "venezuela",
    "iceland",
    "malta",
    "romania",
    "ca-ontario",
    "ca-montreal",
    "ca-toronto",
    "ca-ontario-streaming-optimized",
    "ca-vancouver",
    "hungary",
    "greenland",
    "costa-rica",
    "brazil",
    "argentina",
    "peru",
    "chile",
    "guatemala",
    "uruguay",
    "bolivia",
    "ecuador",
    "mexico",
    "saudi-arabia",
    "united-arab-emirates",
    "panama",
    "qatar",
    "singapore",
    "vietnam",
    "indonesia",
    "nepal",
    "bangladesh",
    "south-korea",
    "colombia",
    "india",
    "au-perth",
    "au-adelaide",
    "au-sydney",
    "au-melbourne",
    "australia-streaming-optimized",
    "au-brisbane",
    "jp-streaming-optimized",
    "jp-tokyo",
    "mongolia",
    "philippines",
    "macao",
    "taiwan",
    "cambodia",
    "hong-kong",
    "malaysia",
    "china",
    "new-zealand",
    "sri-lanka"
    # Add more regions as needed
)

# File paths for tracking state and logging
$indexFile = "C:\Users\Bob22\Documents\Scripts\Logs\CycleAndUpdatehours\currentRegionIndex.txt"
$logFile = "C:\Users\Bob22\Documents\Scripts\Logs\CycleAndUpdatehours\CycleAndUpdatePIA.log"

# =========================================================

# Function to log messages with timestamps
function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
}

# Enable background mode to allow `piactl` commands without GUI
& "$piactlPath" background enable | Out-Null
Log-Message "Background mode enabled."

try {
    Log-Message "===== Starting CycleAndUpdatePIA Script ====="

    # ================== Region Selection ==================
    if ($selectionMode -eq "Sequential") {
        # Read the current region index
        if (Test-Path $indexFile) {
            $currentIndex = (Get-Content $indexFile -Raw).Trim()
            if ([int]::TryParse($currentIndex, [ref]$null)) {
                $currentIndex = [int]$currentIndex
            } else {
                Log-Message "Invalid index found in $indexFile. Resetting to 0."
                $currentIndex = 0
            }
        } else {
            $currentIndex = 0
        }

        # Determine the next region index
        $nextIndex = ($currentIndex + 1) % $regionList.Count
        $nextRegion = $regionList[$nextIndex]

        Log-Message "Sequential Mode - Current Region Index: $currentIndex. Next Region: $nextRegion (Index: $nextIndex)."

    } elseif ($selectionMode -eq "Random") {
        # Read the last selected index to avoid repetition if possible
        if (Test-Path $indexFile) {
            $lastIndex = (Get-Content $indexFile -Raw).Trim()
            if ([int]::TryParse($lastIndex, [ref]$null)) {
                $lastIndex = [int]$lastIndex
            } else {
                $lastIndex = -1
            }
        } else {
            $lastIndex = -1
        }

        # Select a random index different from the last one
        if ($regionList.Count -gt 1) {
            do {
                $nextIndex = Get-Random -Minimum 0 -Maximum $regionList.Count
            } while ($nextIndex -eq $lastIndex)
        } else {
            $nextIndex = 0
        }

        $nextRegion = $regionList[$nextIndex]
        Log-Message "Random Mode - Selected Next Region: $nextRegion (Index: $nextIndex)."
    } else {
        throw "Invalid selection mode: $selectionMode. Use 'Sequential' or 'Random'."
    }
    # ===================================================

    # Get current connection state
    $connectionState = & "$piactlPath" get connectionstate
    Log-Message "Current Connection State: $connectionState."

    if ($connectionState -eq "Connected") {
        Log-Message "PIA is currently connected. Initiating disconnect."
        & "$piactlPath" disconnect
        Start-Sleep -Seconds 10  # Wait for disconnection to complete

        # Verify disconnection
        $postDisconnectState = & "$piactlPath" get connectionstate
        if ($postDisconnectState -ne "Disconnected") {
            Log-Message "Error: Failed to disconnect from PIA."
            throw "Failed to disconnect."
        } else {
            Log-Message "Successfully disconnected from PIA."
        }
    } else {
        Log-Message "PIA is not connected. No need to disconnect."
    }

    # Set the new region
    Log-Message "Setting region to $nextRegion."
    & "$piactlPath" set region "$nextRegion"
    Start-Sleep -Seconds 5  # Brief pause to ensure the region is set

    # Connect to PIA
    Log-Message "Connecting to PIA."
    & "$piactlPath" connect

    # Wait for the connection to establish
    $maxWait = 60  # Maximum wait time in seconds
    $waited = 0
    $connected = $false

    while ($waited -lt $maxWait) {
        $status = & "$piactlPath" get connectionstate
        if ($status -eq "Connected") {
            Log-Message "Successfully connected to $nextRegion."
            $connected = $true
            break
        } else {
            Start-Sleep -Seconds 5
            $waited += 5
            Log-Message "Waiting for connection to $nextRegion to establish... ($waited/$maxWait seconds elapsed)"
        }
    }

    if (-not $connected) {
        Log-Message "Error: Failed to connect to $nextRegion within $maxWait seconds."
        throw "Connection timeout."
    }

    # Update the region index if in Sequential mode
    if ($selectionMode -eq "Sequential") {
        Set-Content -Path $indexFile -Value $nextIndex
        Log-Message "Updated region index to $nextIndex."
    } elseif ($selectionMode -eq "Random") {
        # Update the index file to store the last selected index
        Set-Content -Path $indexFile -Value $nextIndex
        Log-Message "Updated last selected index to $nextIndex."
    }

    # ==================== Added Wait ====================
    # Optional: Additional wait to ensure port forwarding is ready
    Start-Sleep -Seconds 10  # Wait for 10 seconds before retrieving port number
    # ===================================================

    # Retrieve the new port number from PIA
    Log-Message "Retrieving new port number from PIA."
    Start-Sleep -Seconds 10  # Wait for 10 seconds to ensure port number is available
    $portNumber = & "$piactlPath" get portforward
    Log-Message "Port Forwarding Status: $portNumber."

    # Validate the retrieved port number
    if ($portNumber -match '^\d+$') {
        Log-Message "Retrieved port number: $portNumber."

        # Check if the VM is running
        $vmStatusOutput = & "$vboxManagePath" showvminfo "$vmName" --machinereadable
        $vmIsRunning = $vmStatusOutput -match 'VMState="running"'

        if ($vmIsRunning) {
            Log-Message "VM '$vmName' is running. Updating port forwarding rule."

            # Update the port forwarding rule while VM is running
            & "$vboxManagePath" controlvm $vmName natpf1 delete "guestssh" 2>$null
            & "$vboxManagePath" controlvm $vmName natpf1 "guestssh,tcp,,$portNumber,,8000"
            Log-Message "Port forwarding updated successfully while VM is running."
        } else {
            Log-Message "VM '$vmName' is not running. Updating port forwarding rule in VM configuration."

            # Update the port forwarding rule while VM is off
            & "$vboxManagePath" modifyvm $vmName --natpf1 delete "guestssh" 2>$null
            & "$vboxManagePath" modifyvm $vmName --natpf1 "guestssh,tcp,,$portNumber,,8000"
            Log-Message "Port forwarding updated successfully in VM configuration."
        }
    } elseif ($portNumber -in @("Inactive", "Attempting", "Failed", "Unavailable")) {
        Log-Message "Port forwarding status: $portNumber. No port to update."
    } else {
        Log-Message "Error: Unexpected port forwarding status: $portNumber."
        throw "Unexpected port forwarding status."
    }

    Log-Message "===== CycleAndUpdatePIA Script Completed Successfully ====="
} catch {
    Log-Message "Exception Occurred: $_"
}

# =========================================================
