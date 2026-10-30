using System;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using SunJWBase;

namespace FilesHashWUI
{
    public static class Program
    {
        private const string SingleInstanceMutexName = @"Local\fHashWUI.SingleInstance";
        private const string MainWindowTitle = "fHash";

        [STAThread]
        static void Main(string[] args)
        {
            WinRT.ComWrappersSupport.InitializeComWrappers();

            using Mutex mutex = new Mutex(true, SingleInstanceMutexName, out bool createdNew);
            if (!createdNew && !HasPathsArgument(args) && TryActivateExistingWindow())
            {
                Environment.Exit(0);
            }

            Application.Start((p) =>
            {
                var context = new DispatcherQueueSynchronizationContext(
                    DispatcherQueue.GetForCurrentThread());
                SynchronizationContext.SetSynchronizationContext(context);
                new App();
            });

            // A windowless process must not keep the single-instance mutex alive.
            Environment.Exit(0);
        }

        private static bool HasPathsArgument(string[] args)
        {
            foreach (string arg in args)
            {
                if (string.Equals(arg, "-paths", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            return false;
        }

        private static bool TryActivateExistingWindow()
        {
            IntPtr hWnd = FindWindow(null, MainWindowTitle);
            if (hWnd == IntPtr.Zero)
            {
                return false;
            }

            if (Win32Helper.IsWindowMinimized(hWnd))
            {
                Win32Helper.RestoreWindow(hWnd);
            }

            Win32Helper.SetForegroundWindow(hWnd);
            return true;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    }
}
