/// All user-facing strings for the Anima Reader app.
/// Centralized here for easy maintenance and future i18n support.
class S {
  S._();

  // ─── App ───
  static const appTitle = 'Anima Reader';
  static const appSubtitle = 'E-ink Book Reader';

  // ─── Home / Setup Screen ───
  static const setupTitle = 'Set Up Your Ink Library';
  static const setupSubtitle =
      'Connect your GitHub account to sync your books and reading progress.';
  static const fieldPat = 'GitHub PAT (Access Token)';
  static const fieldOwner = 'GitHub Username (Owner)';
  static const fieldRepo = 'Repository Name';
  static const buttonConnect = 'CONNECT LIBRARY';
  static const buttonShowHelp = 'HOW TO SET UP MY LIBRARY?';
  static const buttonHideHelp = 'HIDE SETUP GUIDE';
  static const libraryTitle = 'Anima Library';

  // ─── Setup Help Steps ───
  static const helpStep1Title = 'STEP 1: Create Repository';
  static const helpStep1Body =
      "Create a repository on GitHub (e.g. 'my-books'). "
      'Mark it as PRIVATE and initialize it with a README file (required checkbox).';
  static const helpStep2Title = 'STEP 2: Generate Your Token (PAT)';
  static const helpStep2Body =
      'Go to Settings → Developer Settings → Personal Access Tokens → Tokens (classic).\n'
      "Generate a new token with 'repo' permissions and copy it.";
  static const helpStep3Title = 'STEP 3: Upload Your Books';
  static const helpStep3Body =
      'Upload your .epub or .pdf files directly to the root of the repository. '
      'Do not place them inside folders.';
  static const helpStep4Title = 'STEP 4: Connect';
  static const helpStep4Body =
      "Enter the details above and press Connect. The 'sync.json' file "
      'will be created automatically when you start reading.';

  // ─── Reader Screen ───
  static const loadingContent = 'Loading content...';
  static const loadingBook = 'Loading...';
  static const toggleViewTooltip = 'Toggle original/text view';
  static const pageLabel = 'P.';
  static const chapterLabel = 'Ch.';
  static const errorRenderingPage = 'Error rendering the page image.';
  static const errorProcessingPage = 'Error processing page';
  static const errorReadingEpub = 'Error reading EPUB';
  static const errorLoadingBook = 'Error loading book';
  static const emptyChapter = 'Chapter has no text or uses a complex format.';
  static const unsupportedFormat = 'This format is not supported yet.';

  // ─── Empty Library ───
  static const emptyLibraryTitle = 'Your library is empty';
  static const emptyLibrarySubtitle =
      'Upload .epub or .pdf files to the root of your GitHub repository to get started.';
  static const emptyLibraryButton = 'REFRESH';

  // ─── Settings ───
  static const settingsTitle = 'Settings';
  static const settingsTheme = 'Display Theme';
  static const settingsThemeNormal = 'Normal';
  static const settingsThemeDark = 'Dark';
  static const settingsThemeWarm = 'Warm (Eye Care)';
  static const settingsRefreshInterval = 'E-ink Refresh Interval';
  static const settingsRefreshPages = 'pages';
  static const settingsDisconnect = 'Disconnect Library';
  static const settingsDisconnectConfirm =
      'Are you sure you want to disconnect? Your reading progress is saved in the cloud.';
  static const buttonCancel = 'Cancel';
  static const buttonDisconnect = 'Disconnect';
  static const settingsFontSize = 'Font Size';
  static const settingsDefaultMargin = 'Default Reading Margin';
  static const settingsMarginNone = 'None (0px)';
  static const settingsMarginSmall = 'Small (8px)';
  static const settingsMarginMedium = 'Medium (16px)';
  static const settingsMarginLarge = 'Large (24px)';

  // ─── Errors ───
  static const errorNoConnection =
      'No internet connection. Please check your network.';
  static const errorInvalidToken =
      'Invalid access token. Please check your GitHub PAT.';
  static const errorRepoNotFound =
      'Repository not found. Please verify the owner and repo name.';
  static const errorRateLimit =
      'GitHub API rate limit reached. Please try again later.';
  static const errorUnknown = 'An unexpected error occurred. Please try again.';
  static const errorRetry = 'Retry';

  // ─── Download Progress ───
  static const downloadingBook = 'Downloading';
  static const downloadProgress = 'MB';
}
