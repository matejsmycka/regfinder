#requires -version 2.0

<#
.SYNOPSIS
    Creates an EXE wrapper from a PowerShell script by compressing the script and embedding into
    a newly generated assembly.
.DESCRIPTION
    Creates an EXE wrapper from a PowerShell script by compressing the script and embedding into
    a newly generated assembly.
.PARAMETER Path
    The path to the .
.PARAMETER LiteralPath
    Specifies a path to one or more locations. Unlike Path, the value of LiteralPath is used exactly as it 
    is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose 
    it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any 
    characters as escape sequences.
.PARAMETER OutputAssembly
    The name (including path) of the EXE to generate.
.PARAMETER IconPath
    The path to an optional icon to be embedded as the application icon for the EXE.
.PARAMETER STA
    By default the console app created uses MTAThread.  If this switch is specified, then it uses STAThread.
.EXAMPLE
    C:\PS> .\Make-PS1ExeWrapper.ps1 .\MyScript.ps1 .\MyScript.exe .\app.ico -Sta
    This creates an console application called MyScript.exe that internally hosts the PowerShell
    engine and runs the script specified by MyScript.ps1.  Optionally the file app.ico is
    embedded into the EXE as the application's icon.
.NOTES
    Author: Keith Hill
    Date:   Aug 7, 2010
    Issues: This implementation is more of a feasibility test and isn't fully functional.  It doesn't
            support an number of PSHostUserInterface members as well as a number of PSHostRawUserInterface
            members.  This approach also suffers from the same problem of running script "interactively"
            and not loading it from a file. That is, the entire script output is run through Out-Default
            and PowerShell gets confused.  It formats the first types it sees correctly but after that the
            formatting is off.  To correct this, you have to append | Out-Default where you script outputs
            to the host without using a Write-* cmdlet e.g.:
            
            MyScript.ps1:
            -------------------------------
            Get-Process svchost
            Get-Date | Out-Default
            Dir C:\  | Out-Default
            Dir c:\idontexist | Out-Default
            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'
            Write-Host    "host"
            Write-Warning "warning"
            Write-Verbose "verbose"
            Write-Debug   "debug"
            Write-Error   "error"
#>
[CmdletBinding(DefaultParameterSetName="Path")]
param(
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="Path",
               ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to bitmap file")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $Path,
    
    [Alias("PSPath")]
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="LiteralPath", 
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to bitmap file")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $LiteralPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]
    $OutputAssembly,
    
    [Parameter(Position = 2)]
    [string]
    $IconPath,
    
    [Parameter()]
    [switch]
    $STA
)

Begin {
    Set-StrictMode -Version latest 
    
    $MainAttribute = ''
    $ApartmentState = 'System.Threading.ApartmentState.MTA'
    if ($Sta)
    {
        $MainAttribute = '[STAThread]'
        $ApartmentState = 'System.Threading.ApartmentState.STA'
    }
    
    $src = @'
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Security;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("")]
[assembly: AssemblyDescription("")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("")]
[assembly: AssemblyProduct("")]
//[assembly: AssemblyCopyright("Copyright ©  2013")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")

namespace PS1ToExeTemplate
{
    class Program
    {
        private static object _powerShellLock = new object();
        private static readonly Host _host = new Host();
        private static PowerShell _powerShellEngine;

'@ + @"
$MainAttribute

"@ + @'
        static void Main(string[] args)
        {
            Console.CancelKeyPress += Console_CancelKeyPress;
            Console.TreatControlCAsInput = false;

            string script = GetScript();
            RunScript(script, args, null);
        }

        private static string GetScript()
        {
            string script = String.Empty;

            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream stream = assembly.GetManifestResourceStream("Resources.Script.ps1.gz"))
            {
                var gZipStream = new GZipStream(stream, CompressionMode.Decompress, true);
                var streamReader = new StreamReader(gZipStream);
                script = streamReader.ReadToEnd();
            }

            return script;
        }

        private static void RunScript(string script, string[] args, object input)
        {
            lock (_powerShellLock)
            {
                _powerShellEngine = PowerShell.Create();
            }

            try
            {
                _powerShellEngine.Runspace = RunspaceFactory.CreateRunspace(_host);
                _powerShellEngine.Runspace.ApartmentState = 
'@ + @"                
                $ApartmentState;
                
"@ + @'                
                _powerShellEngine.Runspace.Open();
                _powerShellEngine.AddScript(script);
                _powerShellEngine.AddCommand("Out-Default");
                _powerShellEngine.Commands.Commands[0].MergeMyResults(PipelineResultTypes.Error, PipelineResultTypes.Output);

                if (input != null)
                {
                    _powerShellEngine.Invoke(new[] { input });
                }
                else
                {
                    _powerShellEngine.Invoke();
                }
            }
            finally
            {
                lock (_powerShellLock)
                {
                    _powerShellEngine.Dispose();
                    _powerShellEngine = null;
                }
            }
        }

        private static void Console_CancelKeyPress(object sender, ConsoleCancelEventArgs e)
        {
            try
            {
                lock (_powerShellLock)
                {
                    if (_powerShellEngine != null && _powerShellEngine.InvocationStateInfo.State == PSInvocationState.Running)
                    {
                        _powerShellEngine.Stop();
                    }
                }
                e.Cancel = true;
            }
            catch (Exception ex)
            {
                _host.UI.WriteErrorLine(ex.ToString());
            }
        }
    }

    class Host : PSHost
    {
        private PSHostUserInterface _psHostUserInterface = new HostUserInterface();

        public override void SetShouldExit(int exitCode)
        {
            Environment.Exit(exitCode);
        }

        public override void EnterNestedPrompt()
        {
            throw new NotImplementedException();
        }

        public override void ExitNestedPrompt()
        {
            throw new NotImplementedException();
        }

        public override void NotifyBeginApplication()
        {
        }

        public override void NotifyEndApplication()
        {
        }

        public override string Name
        {
            get { return "PSCX-PS1ToExeHost"; }
        }

        public override Version Version
        {
            get { return new Version(1, 0); }
        }

        public override Guid InstanceId
        {
            get { return new Guid("E4673B42-84B6-4C43-9589-95FAB8E00EB2"); }
        }

        public override PSHostUserInterface UI
        {
            get { return _psHostUserInterface; }
        }

        public override CultureInfo CurrentCulture
        {
            get { return Thread.CurrentThread.CurrentCulture; }
        }

        public override CultureInfo CurrentUICulture
        {
            get { return Thread.CurrentThread.CurrentUICulture; }
        }
    }

    class HostUserInterface : PSHostUserInterface, IHostUISupportsMultipleChoiceSelection
    {
        private PSHostRawUserInterface _psRawUserInterface = new HostRawUserInterface();

        public override PSHostRawUserInterface RawUI
        {
            get { return _psRawUserInterface; }
        }

        public override string ReadLine()
        {
            return Console.ReadLine();
        }

        public override SecureString ReadLineAsSecureString()
        {
            throw new NotImplementedException();
        }

        public override void Write(string value)
        {
            string output = value ?? "null";
            Console.Write(output);
        }

        public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
        {
            string output = value ?? "null";
            var origFgColor = Console.ForegroundColor;
            var origBgColor = Console.BackgroundColor;
            Console.ForegroundColor = foregroundColor;
            Console.BackgroundColor = backgroundColor;
            Console.Write(output);
            Console.ForegroundColor = origFgColor;
            Console.BackgroundColor = origBgColor;
        }

        public override void WriteLine(string value)
        {
            string output = value ?? "null";
            Console.WriteLine(output);
        }

        public override void WriteErrorLine(string value)
        {
            string output = value ?? "null";
            var origFgColor = Console.ForegroundColor;
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine(output);
            Console.ForegroundColor = origFgColor;
        }

        public override void WriteDebugLine(string message)
        {
            WriteYellowAnnotatedLine(message, "DEBUG");
        }

        public override void WriteVerboseLine(string message)
        {
            WriteYellowAnnotatedLine(message, "VERBOSE");
        }

        public override void WriteWarningLine(string message)
        {
            WriteYellowAnnotatedLine(message, "WARNING");
        }

        private void WriteYellowAnnotatedLine(string message, string annotation)
        {
            string output = message ?? "null";
            var origFgColor = Console.ForegroundColor;
            var origBgColor = Console.BackgroundColor;
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.BackgroundColor = ConsoleColor.Black;
            WriteLine(String.Format(CultureInfo.CurrentCulture, "{0}: {1}", annotation, output));
            Console.ForegroundColor = origFgColor;
            Console.BackgroundColor = origBgColor;
        }

        public override void WriteProgress(long sourceId, ProgressRecord record)
        {
            throw new NotImplementedException();
        }

        public override Dictionary<string, PSObject> Prompt(string caption, string message, Collection<FieldDescription> descriptions)
        {
            if (String.IsNullOrEmpty(caption) && String.IsNullOrEmpty(message) && descriptions.Count > 0)
            {
                Console.Write(descriptions[0].Name + ": ");
            }
            else
            {
                this.Write(ConsoleColor.DarkCyan, ConsoleColor.Black, caption + "\n" + message + " ");                
            }
            var results = new Dictionary<string, PSObject>();
            foreach (FieldDescription fd in descriptions)
            {
                string[] label = GetHotkeyAndLabel(fd.Label);
                this.WriteLine(label[1]);
                string userData = Console.ReadLine();
                if (userData == null)
                {
                    return null;
                }

                results[fd.Name] = PSObject.AsPSObject(userData);
            }

            return results;
        }

        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)
        {
            throw new NotImplementedException();
        }

        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)
        {
            throw new NotImplementedException();
        }

        public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice)
        {
            // Write the caption and message strings in Blue.
            this.WriteLine(ConsoleColor.Blue, ConsoleColor.Black, caption + "\n" + message + "\n");

            // Convert the choice collection into something that is
            // easier to work with. See the BuildHotkeysAndPlainLabels 
            // method for details.
            string[,] promptData = BuildHotkeysAndPlainLabels(choices);

            // Format the overall choice prompt string to display.
            var sb = new StringBuilder();
            for (int element = 0; element < choices.Count; element++)
            {
                sb.Append(String.Format(CultureInfo.CurrentCulture, "|{0}> {1} ", promptData[0, element], promptData[1, element]));
            }

            sb.Append(String.Format(CultureInfo.CurrentCulture, "[Default is ({0}]", promptData[0, defaultChoice]));

            // Read prompts until a match is made, the default is
            // chosen, or the loop is interrupted with ctrl-C.
            while (true)
            {
                this.WriteLine(sb.ToString());
                string data = Console.ReadLine().Trim().ToUpper(CultureInfo.CurrentCulture);

                // If the choice string was empty, use the default selection.
                if (data.Length == 0)
                {
                    return defaultChoice;
                }

                // See if the selection matched and return the
                // corresponding index if it did.
                for (int i = 0; i < choices.Count; i++)
                {
                    if (promptData[0, i] == data)
                    {
                        return i;
                    }
                }

                this.WriteErrorLine("Invalid choice: " + data);
            }
        }

        #region IHostUISupportsMultipleChoiceSelection Members

        public Collection<int> PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, IEnumerable<int> defaultChoices)
        {
            this.WriteLine(ConsoleColor.Blue, ConsoleColor.Black, caption + "\n" + message + "\n");

            string[,] promptData = BuildHotkeysAndPlainLabels(choices);

            var sb = new StringBuilder();
            for (int element = 0; element < choices.Count; element++)
            {
                sb.Append(String.Format(CultureInfo.CurrentCulture, "|{0}> {1} ", promptData[0, element], promptData[1, element]));
            }

            var defaultResults = new Collection<int>();
            if (defaultChoices != null)
            {
                int countDefaults = 0;
                foreach (int defaultChoice in defaultChoices)
                {
                    ++countDefaults;
                    defaultResults.Add(defaultChoice);
                }

                if (countDefaults != 0)
                {
                    sb.Append(countDefaults == 1 ? "[Default choice is " : "[Default choices are ");
                    foreach (int defaultChoice in defaultChoices)
                    {
                        sb.AppendFormat(CultureInfo.CurrentCulture, "\"{0}\",", promptData[0, defaultChoice]);
                    }
                    sb.Remove(sb.Length - 1, 1);
                    sb.Append("]");
                }
            }

            this.WriteLine(ConsoleColor.Cyan, ConsoleColor.Black, sb.ToString());

            var results = new Collection<int>();
            while (true)
            {
            ReadNext:
                string prompt = string.Format(CultureInfo.CurrentCulture, "Choice[{0}]:", results.Count);
                this.Write(ConsoleColor.Cyan, ConsoleColor.Black, prompt);
                string data = Console.ReadLine().Trim().ToUpper(CultureInfo.CurrentCulture);

                if (data.Length == 0)
                {
                    return (results.Count == 0) ? defaultResults : results;
                }

                for (int i = 0; i < choices.Count; i++)
                {
                    if (promptData[0, i] == data)
                    {
                        results.Add(i);
                        goto ReadNext;
                    }
                }

                this.WriteErrorLine("Invalid choice: " + data);
            }
        }

        #endregion

        private static string[,] BuildHotkeysAndPlainLabels(Collection<ChoiceDescription> choices)
        {
            // Allocate the result array
            string[,] hotkeysAndPlainLabels = new string[2, choices.Count];

            for (int i = 0; i < choices.Count; ++i)
            {
                string[] hotkeyAndLabel = GetHotkeyAndLabel(choices[i].Label);
                hotkeysAndPlainLabels[0, i] = hotkeyAndLabel[0];
                hotkeysAndPlainLabels[1, i] = hotkeyAndLabel[1];
            }

            return hotkeysAndPlainLabels;
        }

        private static string[] GetHotkeyAndLabel(string input)
        {
            string[] result = new string[] { String.Empty, String.Empty };
            string[] fragments = input.Split('&');
            if (fragments.Length == 2)
            {
                if (fragments[1].Length > 0)
                {
                    result[0] = fragments[1][0].ToString().
                    ToUpper(CultureInfo.CurrentCulture);
                }

                result[1] = (fragments[0] + fragments[1]).Trim();
            }
            else
            {
                result[1] = input;
            }

            return result;
        }
    }

    class HostRawUserInterface : PSHostRawUserInterface
    {
        public override KeyInfo ReadKey(ReadKeyOptions options)
        {
            throw new NotImplementedException();
        }

        public override void FlushInputBuffer()
        {
        }

        public override void SetBufferContents(Coordinates origin, BufferCell[,] contents)
        {
            throw new NotImplementedException();
        }

        public override void SetBufferContents(Rectangle rectangle, BufferCell fill)
        {
            throw new NotImplementedException();
        }

        public override BufferCell[,] GetBufferContents(Rectangle rectangle)
        {
            throw new NotImplementedException();
        }

        public override void ScrollBufferContents(Rectangle source, Coordinates destination, Rectangle clip, BufferCell fill)
        {
            throw new NotImplementedException();
        }

        public override ConsoleColor ForegroundColor
        {
            get { return Console.ForegroundColor; }
            set { Console.ForegroundColor = value; }
        }

        public override ConsoleColor BackgroundColor
        {
            get { return Console.BackgroundColor; }
            set { Console.BackgroundColor = value; }
        }

        public override Coordinates CursorPosition
        {
            get { return new Coordinates(Console.CursorLeft, Console.CursorTop); }
            set { Console.SetCursorPosition(value.X, value.Y); }
        }

        public override Coordinates WindowPosition
        {
            get { return new Coordinates(Console.WindowLeft, Console.WindowTop); }
            set { Console.SetWindowPosition(value.X, value.Y); }
        }

        public override int CursorSize
        {
            get { return Console.CursorSize; }
            set { Console.CursorSize = value; }
        }

        public override Size BufferSize
        {
            get { return new Size(Console.BufferWidth, Console.BufferHeight); }
            set { Console.SetBufferSize(value.Width, value.Height); }
        }

        public override Size WindowSize
        {
            get { return new Size(Console.WindowWidth, Console.WindowHeight); }
            set { Console.SetWindowSize(value.Width, value.Height); }
        }

        public override Size MaxWindowSize
        {
            get { return new Size(Console.LargestWindowWidth, Console.LargestWindowHeight); }
        }

        public override Size MaxPhysicalWindowSize
        {
            get { return new Size(Console.LargestWindowWidth, Console.LargestWindowHeight); }
        }

        public override bool KeyAvailable
        {
            get { return Console.KeyAvailable; }
        }

        public override string WindowTitle
        {
            get { return Console.Title; }
            set { Console.Title = value; }
        }
    }
}
'@
}    

Process {
    if ($psCmdlet.ParameterSetName -eq "Path")
    {
        # In the -Path (non-literal) case we may need to resolve a wildcarded path
        $resolvedPaths = @($Path | Resolve-Path | Convert-Path)
    }
    else 
    {
        # Must be -LiteralPath
        $resolvedPaths = @($LiteralPath | Convert-Path)
    }
 
    foreach ($rpath in $resolvedPaths) 
    {
        Write-Verbose "Processing $rpath"

        $gzItem = Get-ChildItem $rpath | Write-GZip -Quiet 
        $resourcePath = "$($gzItem.Directory)\Resources.Script.ps1.gz"
        if (Test-Path $resourcePath) { Remove-Item $resourcePath }
        Rename-Item $gzItem $resourcePath
        
        # Configure the compiler parameters
        $referenceAssemblies = 'System.dll',([psobject].Assembly.Location)
        $outputPath = $OutputAssembly
        if (![IO.Path]::IsPathRooted($outputPath))
        {
            $outputPath = [io.path]::GetFullPath((Join-Path $pwd $outputPath))
        }
        if ($rpath -eq $outputPath)
        { 
            throw 'Oops, you don''t really want to overwrite your script with an EXE.' 
        }

        $cp = new-object System.CodeDom.Compiler.CompilerParameters $referenceAssemblies,$outputPath,$true
        $cp.TempFiles = new-object System.CodeDom.Compiler.TempFileCollection ([IO.Path]::GetTempPath())
        $cp.GenerateExecutable = $true
        $cp.GenerateInMemory   = $false
        $cp.IncludeDebugInformation = $true
        if ($IconPath) 
        {
            $rIconPath = Resolve-Path $IconPath
            $cp.CompilerOptions = " /win32icon:$rIconPath"
        }
        [void]$cp.EmbeddedResources.Add($resourcePath)
        
        # Create the C# codedom compiler
        $dict = new-object 'System.Collections.Generic.Dictionary[string,string]' 
        $dict.Add('CompilerVersion','v3.5')
        $provider = new-object Microsoft.CSharp.CSharpCodeProvider $dict
        
        # Compile the source and report errors
        $results = $provider.CompileAssemblyFromSource($cp, $src)
        if ($results.Errors.Count)
        {
            $errorLines = "" 
            foreach ($error in $results.Errors) 
            { 
                $errorLines += "`n`t" + $error.Line + ":`t" + $error.ErrorText 
            }
            Write-Error $errorLines
        }
    }  
}