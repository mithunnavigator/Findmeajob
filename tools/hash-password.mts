// Prints a hash of the password in DOSSIER_NEW_PASSWORD, for DOSSIER_PASSWORD.
// The password comes through the environment so it never shows up in a
// process list. Used by findmeajob.ps1.
import { hashPassword } from "../app/src/lib/auth/password-hash.ts";

const password = process.env.DOSSIER_NEW_PASSWORD ?? "";
if (!password) {
  console.error("No password given.");
  process.exit(1);
}
console.log(await hashPassword(password));
