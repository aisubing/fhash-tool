using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace FilesHashWUI
{
    /// <summary>
    /// Provides application-specific behavior to supplement the default Application class.
    /// </summary>
    public partial class App : Application
    {
        private MainWindow m_mainWindow;
        private DispatcherQueue m_dispatcherQueue;

        /// <summary>
        /// Initializes the singleton application object.  This is the first line of authored code
        /// executed, and as such is the logical equivalent of main() or WinMain().
        /// </summary>
        public App()
        {
            InitializeComponent();
        }

        /// <summary>
        /// Invoked when the application is launched.
        /// </summary>
        /// <param name="args">Details about the launch request and process.</param>
        protected override void OnLaunched(LaunchActivatedEventArgs args)
        {
            m_dispatcherQueue = DispatcherQueue.GetForCurrentThread();
            if (m_mainWindow == null)
            {
                m_mainWindow = new MainWindow();
                m_mainWindow.Activate();
            }
            else
            {
                m_mainWindow.ActivateWindow();
            }
        }

        public void OnRedirected(AppActivationArguments args)
        {
            DispatcherQueue dispatcher = m_dispatcherQueue ?? m_mainWindow?.DispatcherQueue;
            dispatcher?.TryEnqueue(() =>
            {
                if (m_mainWindow == null)
                {
                    m_mainWindow = new MainWindow();
                    m_mainWindow.Activate();
                }

                m_mainWindow.ActivateWindow();
                m_mainWindow.OnRedirected(args);
            });
        }

        public void OnMainWindowClosed()
        {
            m_mainWindow = null;
        }
    }
}
