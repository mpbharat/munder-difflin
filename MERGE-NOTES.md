# Fork Merge Notes

- `MD_USER_DATA` override in `src/main/index.ts` (`app.setPath('userData', process.env.MD_USER_DATA)`) must run before any import-time call to `app.getPath('userData')`. When merging upstream changes, make sure this override stays ahead of any new/moved code that reads `userData` at module load time, or multi-office isolation (office-kps.command / office-personal.command) silently breaks.
