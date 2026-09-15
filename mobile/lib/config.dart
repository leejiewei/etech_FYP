/// Where the database is, and the key used to reach it.
///
/// This file used to hold the address of the PC running Apache, because
/// the app read everything through the shop's PHP API and the phone is a
/// separate machine from that PC. Getting that address right was the one
/// setting that had to be correct or nothing worked — hence the "Server
/// settings" dialog buried in the Account tab, and the 10.0.2.2 trick for
/// the Android emulator.
///
/// None of that applies any more. The app talks to Supabase, which is at a
/// fixed address on the internet, so the emulator, a real handset and the
/// website all reach exactly the same place with no configuration at all.
///
/// The key below is the *publishable* key. It identifies the project and
/// grants nothing: every request it makes arrives at Postgres as the
/// "anon" role, and Row Level Security decides what that role may see.
/// Supabase intends this key to be shipped inside an app bundle, and the
/// website carries the same one in web/js/config.js.
///
/// The key that must never be here is the service_role key. It ignores
/// every policy in the database.
class Config {
  static const String supabaseUrl = 'https://asawhkjvturznjitsqfk.supabase.co';
  static const String supabaseKey = 'sb_publishable_hHm6s61BKP01tIR59CoKQg_Jx3NCFDy';

  /// Where the website lives.
  ///
  /// The app needs this for exactly one thing: a password reset link has to
  /// land on a page that can finish the reset, and that page is the
  /// website's. Supabase only honours a redirect that is in the project's
  /// allow-list, so this must stay the deployed origin -- the wildcard
  /// https://etech-fyp.vercel.app/** already covers the page below.
  static const String webOrigin = 'https://etech-fyp.vercel.app';

  /// The drawn illustrations used to be fetched from the website over
  /// HTTP. They are bundled into the app now, so a product picture no
  /// longer depends on a web server being reachable. Only real uploaded
  /// photos come over the network, and those come from Supabase Storage.
  static String illustration(String slug) => 'assets/images/$slug.svg';
}
