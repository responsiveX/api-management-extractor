# PSScriptAnalyzer settings for the powershell-standards skill.
@{
    Severity     = @('Error', 'Warning', 'Information')

    # The default rules flag these, but the scripts do them on purpose:
    # - status lines go through Write-Host
    # - -WhatIf belongs to the script; a New-* helper that builds an object needs none
    # PSAvoidUsingPositionalParameters is off. In PSScriptAnalyzer 1.25, rules that run in
    # parallel can fail with a NullReferenceException in CommandInfo.ResolveParameter, and this
    # rule makes it happen in most runs. The skill's written rule covers named parameters. When
    # a fixed version is out, enable it with
    # CommandAllowList = @('Join-Path', 'az', 'dotnet', 'git', 'npm', 'npx', 'pwsh').
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingPositionalParameters',
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules        = @{

        PSPlaceOpenBrace                   = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        # else, elseif, catch and finally go on a new line after the closing brace.
        PSPlaceCloseBrace                  = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation         = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace          = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckSeparator                          = $true
            CheckParameter                          = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSAlignAssignmentStatement         = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSAvoidUsingCmdletAliases          = @{
            Enable = $true
        }

        PSUseCorrectCasing                 = @{
            Enable = $true
        }

        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }
    }
}
