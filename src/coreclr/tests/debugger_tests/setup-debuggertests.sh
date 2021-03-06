#!/bin/bash

function print_usage {
    echo ''
    echo 'debuggertests install and deploy script.'
    echo ''
    echo 'Required arguments:'
    echo '  --coreclrBinDir=<path>      : Directory of CoreCLR build'
    echo '  --outputDir=<path>          : Directory of debuggertests will be deployed'
    echo '  --nugetCacheDir=<path>      : Directory of nuget cache'
    echo '  --cli=<path>                : Directory of nuget cache'
    echo ''
    echo ''
}

# Argument variables
coreclrBinDir=
outputDir=
nugetCacheDir=
cliPath=

for i in "$@"
do
    case $i in
        -h|--help)
            print_usage
            exit $EXIT_CODE_SUCCESS
            ;;
        --coreclrBinDir=*)
            coreclrBinDir=${i#*=}
            ;;
        --outputDir=*)
            outputDir=${i#*=}
            ;;
        --nugetCacheDir=*)
            nugetCacheDir=${i#*=}
            ;;
        --cli=*)
            cliPath=${i#*=}
            ;;
        *)
            echo "Unknown switch: $i"
            print_usage
            exit $EXIT_CODE_SUCCESS
            ;;
    esac
done

if [ -z "$coreclrBinDir" ] || [ -z "$outputDir" ] || [ -z "$nugetCacheDir" ]; then
    print_usage
    exit 1
fi

debuggerTestsURL=
OSName=$(uname -s)
case $OSName in
    Darwin)
        debuggerTestsURL=https://dotnetbuilddrops.blob.core.windows.net/debugger-container/OSX.DebuggerTests.tar
        ;;

    Linux)
        if [ ! -e /etc/os-release ]; then
            echo "Cannot determine Linux distribution, using the default debuggertests linux build ."
            debuggerTestsURL=https://dotnetbuilddrops.blob.core.windows.net/debugger-container/Linux.DebuggerTests.tar
        else
            source /etc/os-release
            if [ "$ID.$VERSION_ID" == "ubuntu.14.04" ]; then
                debuggerTestsURL=https://dotnetbuilddrops.blob.core.windows.net/debugger-container/Linux.DebuggerTests.tar
            fi
        fi
        ;;
    *)
        echo "Unsupported OS $OSName detected. Can't download debuggertests for this OS."
        exit 0
        ;;

esac

if [ -z "$debuggerTestsURL" ]
then
    echo "Cannot download debuggertests for this Linux distribution"
    exit 0
fi

installDir=$outputDir/debuggertests
if [ -e "$installDir" ]; then 
    rm -rf $installDir 
fi 

mkdir -p $installDir
debuggertestsZipFilePath=$installDir/debuggertests.tar

which curl > /dev/null 2> /dev/null
echo "Download debuggertests to $debuggertestsZipFilePath"
if [ $? -ne 0 ]; then
    echo "wget -q -O $debuggertestsZipFilePath $debuggerTestsURL"
    wget -q -O $debuggertestsZipFilePath $debuggerTestsURL
else
    echo "curl --retry 10 -sSL --create-dirs -o $debuggertestsZipFilePath $debuggerTestsURL"
    curl --retry 10 -sSL --create-dirs -o $debuggertestsZipFilePath $debuggerTestsURL
fi

echo ""
echo "Deploy $debuggertestsZipFilePath to $installDir"
tar -xvf $debuggertestsZipFilePath -C $installDir 

echo ""
echo "Setting up config for debugger tests"
sh $0/ConfigFilesGenerators/GenerateConfig.sh rt=$coreclrBinDir nc=$nugetCacheDir cli=$cliPath
mv Debugger.Tests.Config.txt $installDir/Debugger.Tests/dotnet/Debugger.Tests.Config.txt
exit 0