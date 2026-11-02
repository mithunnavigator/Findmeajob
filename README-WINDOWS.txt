FINDMEAJOB ON WINDOWS (no Docker) - version 1.11.0
================================================

Everything Findmeajob needs lives in this folder: a portable Node.js 24, a
portable PostgreSQL 18 database, and Chromium for printing PDFs. Nothing is
installed system-wide and nothing runs as a Windows service.

  Start Findmeajob.cmd     Starts the database and Findmeajob, then opens
                        http://localhost:3210 in your browser. (Port 3210,
                        so it doesn't clash with other dev servers on 3000.)
  Stop Findmeajob.cmd      Stops both (run it before shutting down if you like;
                        it's safe either way).
  Change Password.cmd   Sets a new sign-in password (only a hash is stored).

Shortcuts for Start and Stop are on your desktop.

Findmeajob only listens on this computer (localhost); nothing on your network
can reach it.

AI MODEL: LM STUDIO (set up)
  Findmeajob uses LM Studio on this computer: address http://127.0.0.1:1234,
  model qwen/qwen3-4b-2507 (Qwen3 4B). Findmeajob loads the model itself with
  the context it needs. Qwen3 4B fits entirely on this laptop's 6 GB
  graphics card, so it's several times faster than Qwen3 8B (also
  downloaded). To go back to 8B: Settings -> AI provider -> qwen/qwen3-8b.

  LM Studio's server must be on while you use Findmeajob's AI features:
  LM Studio -> Settings -> Local Model API -> turn the server on, or run
      "C:\Users\mithu\.lmstudio\bin\lms.exe" server start --port 1234

  How long importing a 1,500-word resume takes on this laptop:
    Qwen3 4B   about 2 minutes
    Qwen3 8B   about 11 minutes (tailored resume + letter: about 5-10 minutes)
  Whichever model you use, check what an import sorts: it can miss
  certifications or put dates in the wrong box.
  Leave the page open (or come back later: the work carries on). Each AI
  step may take up to 30 minutes (DOSSIER_AI_TIMEOUT_SECONDS in app\.env).

  Other choices in Settings -> AI provider: Ollama ("Local model",
  http://localhost:11434), or a hosted provider (OpenAI-compatible,
  Anthropic, Mistral) with an API key - faster, but your profile is sent to it.

WHERE THINGS ARE
  app\             Findmeajob 1.11.0 (with the Windows changes)
  app-1.9.2\       the previous version, kept in case you need to go back
  data\pg          the PostgreSQL database (your profile and applications)
  data\files       nightly backups and export files
  data\upgrade-backups\dossier-before-1.11.0.dump
                   a copy of the database from just before the upgrade
  logs\            logs, if something goes wrong
  app\.env         settings and secrets - keep this file private

BACKING UP
  Settings -> Your data -> Export gives one JSON file with everything.
  Nightly backups are written to data\files\backups (while Findmeajob runs).
  To back up the whole install, stop Findmeajob and copy this folder.

CHANGES MADE TO THE ORIGINAL APP (re-apply them when updating)
  Findmeajob is Dossier 1.11.0 (github.com/AienTech/dossier), renamed.
  - The name: every "Dossier" the app shows became "Findmeajob" (in src and
    e2e).
  - The logo: the MS shield, cut from data\logo-original.webp, in
    public\logo.png (shown by src\components\brand-mark.tsx), src\app\icon.png,
    favicon.ico, apple-icon.png, and findmeajob.ico for the shortcuts.
  - GitHub links and update checks point to github.com/mithunnavigator/Findmeajob
    (src\lib\releases.ts and the PRIVACY.md and wiki links).
    Internal names stay as they were, so saved data keeps working: the
    DOSSIER_* settings, the "dossier" database, export files, encrypted keys,
    and the name it gives job sites' robots.txt.
  - LM Studio's default address is http://127.0.0.1:1234 (not the Docker one),
    with help text pointing to LM Studio's Local Model API settings.
  - src\instrumentation.ts lifts Node's 5-minute limit on waiting for a reply,
    so slow local models can finish (uses the undici package).
  - Test files accept Windows paths, line breaks and yarn.cmd.
  - Build Findmeajob in the folder it will run from: the build links libraries
    by full path. (Start Findmeajob repairs these links if the folder moves.)
