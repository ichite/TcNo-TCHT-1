# Copyright (C) 2023 TroubleChute (Wesley Pyburn)
# Licensed under the GNU General Public License v3.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.gnu.org/licenses/gpl-3.0.en.html
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# ----------------------------------------
# This function gets and/or sets the TCHT install path.
# ----------------------------------------

function Get-TCHTPathSaved() {
    $os = [System.Environment]::OSVersion.Platform.ToString()

    switch ($os) {
        "Win32NT" {
            $registryPath = "HKCU:\Software\TCHT"
            if (Test-Path $registryPath) {
                return (Get-ItemProperty $registryPath).Path
            } else {
                return ""
            }
            break
        }
        "Unix" {
            # If gsettings installed:
            if (command -v gsettings) {
                Write-Host "gsettings is installed"
                
                $gsettingsValue = $(gsettings get tc.ht path 2> $null)
                if ($LASTEXITCODE -eq 0) {
                    return $gsettingsValue.Trim("`"'")
                }
            }

            return ""
            break
        }
        default {
            throw "Unsupported operating system."
        }
    }
}


function Get-TCHTPathFromUser() {
    $os = [System.Environment]::OSVersion.Platform.ToString()

    switch ($os) {
        "Win32NT" {
            if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Host "This script needs to be run as an administrator.`nProcess can try to continue, but will likely fail. Press Enter to continue..." -ForegroundColor Red
                Read-Host
            }

            $path = "C:\TCHT"
            break
        }
        "Unix" {
            $uname = $(uname)
            if ($uname -eq "Darwin") {
                $path = Join-Path (Resolve-Path "~/Documents") "TCHT"
            } else {
                $path = "/home/TCHT"
            }
            break
        }
        default {
            throw "Unsupported operating system."
        }
    }


    # Ask the user where to install
    $installLocation = Read-Host @"
Pick where to install:
1. (default) $path
2. Current folder: $((Get-Location).Path)
or Enter a custom path
"@

    $firstLoop = $True
    if ($installLocation -in "1", "", " ") {
        $installLocation = $path
        if (!(Test-Path $installLocation -PathType Container)) {
            Write-Host "Folder created: $installLocation"
            New-Item -ItemType Directory -Path $installLocation | Out-Null
        }        
    }
    elseif ($installLocation -eq "2") {
        $installLocation = (Get-Location).Path
        if (!(Test-Path $installLocation -PathType Container)) {
            Write-Host "Folder created: $installLocation"
            New-Item -ItemType Directory -Path $installLocation | Out-Null
        }
    }
    # Else, a custom path entered. Check the path exists and prompt about spaces.
    do {
        if (-not $firstLoop) {
            $installLocation = Read-Host "Please enter a custom path"
            $firstLoop = $False
        } else {
            if (!(Test-Path $installLocation -PathType Container)) {
                $createFolder = Read-Host "The folder $installLocation does not exist. Do you want to create it? (Y/N)"
                if ($createFolder -eq "Y" -or $createFolder -eq "y") {
                    Write-Host "Folder created: $installLocation"
                    New-Item -ItemType Directory -Path $installLocation | Out-Null
                }
            }            
        }
        if ($installLocation.Contains(" ")) {
            $proceedAnyway = Read-Host "Using a path with a space can result in things not working properly. Enter another path or type Y to use the current path: $installPath"
        }
    } while ($installLocation.Contains(" ") -and $proceedAnyway -notin 'Y', 'y')

    Write-Host "Saving path..."
    Set-TCHTPath -Path $installLocation

    Write-Host "Installing this, and future TC.HT programs to: $installLocation"
    return $installLocation
}


function Install-GSettings {
    $os = [System.Environment]::OSVersion.Platform.ToString()

    switch ($os) {
        "Win32NT" {
            Write-Host "You only need GSettings on Mac or Linux."
            return
        }
        "Unix" {
            if (which apt-get) {
                # Ubuntu, Debian, Raspbian, Kali, etc.
                apt-get update
                apt-get install -y gsettings-ubuntu-schemas
                if (command -v gsettings) { return }
            }
            if (which dnf) {
                # Fedora, RedHat, CentOS, etc.
                dnf install -y gsettings-desktop-schemas
                if (command -v gsettings) { return }
            }
            if (which yum) {
                # CentOS, RedHat, etc.
                yum install -y gsettings-desktop-schemas
                if (command -v gsettings) { return }
            }
            if (which apk) {
                # Alpine, etc.
                apk update
                apk add glib-dev
                apk add gsettings-desktop-schemas
                if (command -v gsettings) { return }
            }
            if (which pacman) {
                # Pacman
                pacman -S glib2
                if (command -v gsettings) { return }
            }
            
            Write-Error "Could not find a package manager to install gsettings."
            break
        }
        default {
            throw "Unsupported operating system."
        }
    }
}


function Set-TCHTPath() {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $os = [System.Environment]::OSVersion.Platform.ToString()

    switch ($os) {
        "Win32NT" {
            $registryPath = "HKCU:\Software\TCHT"
            if (Test-Path $registryPath) {
                Set-ItemProperty $registryPath -Name Path -Value $path
            } else {
                New-Item -Path $registryPath -Force | Out-Null
                New-ItemProperty -Path $registryPath -Name Path -Value $path -PropertyType String | Out-Null
            }
            break
        }
        "Unix" {
            if (command -v gsettings) {
                Write-Host "gsettings installed."
                if (!(command -v glib-compile-schemas)) {
                    Write-Host "glib not installed. Installing..."
                    brew install glib
                }

                # Install schema
                @"
<?xml version="1.0" encoding="UTF-8"?>
<schemalist>
  <schema id="tc.ht" path="/org/gnome/tc/ht/">
    <key name="path" type="s">
      <default>'/Users/mish/Documents/TCHT'</default>
      <summary>Path for TCHT</summary>
      <description>Path where TCHT files are located.</description>
    </key>
  </schema>
</schemalist>
"@ | Set-Content -Path ./tc.ht.gschema.xml
                
                $SchemaDir = "$HOME/.local/share/glib-2.0/schemas"
                if (-not (Test-Path -Path $SchemaDir)) {
                    New-Item -ItemType Directory -Path $SchemaDir -Force
                }

                glib-compile-schemas . --strict --targetdir=$HOME/.local/share/glib-2.0/schemas
                $Env:GSETTINGS_SCHEMA_DIR="$HOME/.local/share/glib-2.0/schemas"
                
                Write-Host "Saving gsettings path as /tc.ht/path, $path"
                gsettings set tc.ht path "/Users/mish/Documents/TCHT"
            } else {
                # If not gsettings installed:
                if (! $(command -v gsettings)) {
                    Write-Host "gsettings not installed. Installing..."
                    Install-GSettings
                }

                Write-Host "Saving gsettings path as /tc.ht/path, $path"
                # If gsettings installed:
                gsettings write "/tcht/path" "$path"
            }
            break
        }
        default {
            throw "Unsupported operating system."
        }
    }

}

function Get-TCHTPath() {
    $path = Get-TCHTPathSaved
    if ($path -eq "") {
        $path = Get-TCHTPathFromUser
    }

    # We'll create $TCHT if it doesn't already exist:
    if (!(Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path
    }
    return $path
}